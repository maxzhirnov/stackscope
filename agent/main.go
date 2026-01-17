package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type metricsPayload struct {
	CPUUsage    float64 `json:"cpu_usage"`
	MemoryUsage float64 `json:"memory_usage"`
	DiskUsage   float64 `json:"disk_usage"`
	LoadAvg     float64 `json:"load_avg"`
	CollectedAt string  `json:"collected_at"`
}

type cpuSample struct {
	Idle  uint64
	Total uint64
}

func main() {
	addr := flag.String("addr", ":9100", "listen address")
	token := flag.String("token", os.Getenv("STACKSCOPE_TOKEN"), "auth token")
	flag.Parse()

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
		if !authorized(r, *token) {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte("unauthorized"))
			return
		}

		payload, err := collectMetrics()
		if err != nil {
			log.Printf("collect metrics failed: %v", err)
			w.WriteHeader(http.StatusInternalServerError)
			_, _ = w.Write([]byte("metrics unavailable"))
			return
		}

		w.Header().Set("Content-Type", "application/json")
		encoder := json.NewEncoder(w)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(payload); err != nil {
			log.Printf("encode metrics failed: %v", err)
		}
	})

	server := &http.Server{
		Addr:              *addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("stackscope agent listening on %s", *addr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func authorized(r *http.Request, token string) bool {
	if token == "" {
		return true
	}
	if r.Header.Get("X-Stackscope-Token") == token {
		return true
	}
	return r.URL.Query().Get("token") == token
}

func collectMetrics() (metricsPayload, error) {
	cpuUsage, err := readCPUUsage(150 * time.Millisecond)
	if err != nil {
		return metricsPayload{}, err
	}

	memUsage, err := readMemoryUsage()
	if err != nil {
		return metricsPayload{}, err
	}

	diskUsage, err := readDiskUsage("/")
	if err != nil {
		return metricsPayload{}, err
	}

	loadAvg, err := readLoadAvg()
	if err != nil {
		return metricsPayload{}, err
	}

	return metricsPayload{
		CPUUsage:    cpuUsage,
		MemoryUsage: memUsage,
		DiskUsage:   diskUsage,
		LoadAvg:     loadAvg,
		CollectedAt: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

func readCPUUsage(delay time.Duration) (float64, error) {
	a, err := readCPUSample()
	if err != nil {
		return 0, err
	}
	if delay > 0 {
		time.Sleep(delay)
	}
	b, err := readCPUSample()
	if err != nil {
		return 0, err
	}

	total := float64(b.Total - a.Total)
	idle := float64(b.Idle - a.Idle)
	if total <= 0 {
		return 0, fmt.Errorf("cpu total diff <= 0")
	}
	usage := (total - idle) / total * 100
	if usage < 0 {
		usage = 0
	}
	if usage > 100 {
		usage = 100
	}
	return usage, nil
}

func readCPUSample() (cpuSample, error) {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return cpuSample{}, err
	}
	lines := strings.Split(string(data), "\n")
	if len(lines) == 0 {
		return cpuSample{}, fmt.Errorf("empty /proc/stat")
	}
	fields := strings.Fields(lines[0])
	if len(fields) < 5 {
		return cpuSample{}, fmt.Errorf("unexpected /proc/stat format")
	}

	var total uint64
	values := fields[1:]
	for _, v := range values {
		parsed, err := strconv.ParseUint(v, 10, 64)
		if err != nil {
			return cpuSample{}, err
		}
		total += parsed
	}

	idle, err := strconv.ParseUint(fields[4], 10, 64)
	if err != nil {
		return cpuSample{}, err
	}

	return cpuSample{Idle: idle, Total: total}, nil
}

func readMemoryUsage() (float64, error) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, err
	}

	var total, available uint64
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		switch fields[0] {
		case "MemTotal:":
			total, err = strconv.ParseUint(fields[1], 10, 64)
			if err != nil {
				return 0, err
			}
		case "MemAvailable:":
			available, err = strconv.ParseUint(fields[1], 10, 64)
			if err != nil {
				return 0, err
			}
		}
		if total > 0 && available > 0 {
			break
		}
	}

	if total == 0 {
		return 0, fmt.Errorf("mem total is zero")
	}
	used := float64(total-available) / float64(total) * 100
	if used < 0 {
		used = 0
	}
	if used > 100 {
		used = 100
	}
	return used, nil
}

func readDiskUsage(path string) (float64, error) {
	var stat syscall.Statfs_t
	if err := syscall.Statfs(path, &stat); err != nil {
		return 0, err
	}
	if stat.Blocks == 0 {
		return 0, fmt.Errorf("disk blocks is zero")
	}
	used := float64(stat.Blocks-stat.Bavail) / float64(stat.Blocks) * 100
	if used < 0 {
		used = 0
	}
	if used > 100 {
		used = 100
	}
	return used, nil
}

func readLoadAvg() (float64, error) {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return 0, err
	}
	fields := strings.Fields(string(data))
	if len(fields) == 0 {
		return 0, fmt.Errorf("unexpected /proc/loadavg format")
	}
	value, err := strconv.ParseFloat(fields[0], 64)
	if err != nil {
		return 0, err
	}
	return value, nil
}
