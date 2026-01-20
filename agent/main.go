package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

type metricsPayload struct {
	CPUUsage     float64   `json:"cpu_usage"`
	MemoryUsage  float64   `json:"memory_usage"`
	DiskUsage    float64   `json:"disk_usage"`
	LoadAvg      float64   `json:"load_avg"`
	AgentVersion string    `json:"agent_version"`
	UptimeSec    int64     `json:"uptime_seconds"`
	SwapUsage    float64   `json:"swap_usage"`
	DiskReadBps  int64     `json:"disk_read_bps"`
	DiskWriteBps int64     `json:"disk_write_bps"`
	NetRxBps     int64     `json:"net_rx_bps"`
	NetTxBps     int64     `json:"net_tx_bps"`
	FSUsage      []fsUsage `json:"fs_usage"`
	CollectedAt  string    `json:"collected_at"`
}

type extendedPayload struct {
	metricsPayload
	Meta      metaInfo      `json:"meta,omitempty"`
	System    systemInfo    `json:"system,omitempty"`
	CPU       cpuInfo       `json:"cpu,omitempty"`
	Memory    memoryInfo    `json:"memory,omitempty"`
	Disk      diskInfo      `json:"disk,omitempty"`
	Network   networkInfo   `json:"network,omitempty"`
	Processes processesInfo `json:"processes,omitempty"`
	Health    healthInfo    `json:"health,omitempty"`
	Time      timeInfo      `json:"time,omitempty"`
}

type metaInfo struct {
	SchemaVersion int       `json:"schema_version"`
	AgentBuild    buildInfo `json:"agent_build,omitempty"`
	Capabilities  []string  `json:"capabilities,omitempty"`
}

type buildInfo struct {
	GitSHA    string `json:"git_sha,omitempty"`
	BuildTime string `json:"build_time,omitempty"`
}

type systemInfo struct {
	Hostname       string             `json:"hostname,omitempty"`
	FQDN           string             `json:"fqdn,omitempty"`
	OS             osInfo             `json:"os,omitempty"`
	Kernel         string             `json:"kernel,omitempty"`
	Arch           string             `json:"arch,omitempty"`
	Virtualization virtualizationInfo `json:"virtualization,omitempty"`
	BootTime       string             `json:"boot_time,omitempty"`
}

type virtualizationInfo struct {
	Type string `json:"type,omitempty"`
	Role string `json:"role,omitempty"`
}

type osInfo struct {
	Name       string `json:"name,omitempty"`
	Version    string `json:"version,omitempty"`
	PrettyName string `json:"pretty_name,omitempty"`
}

type cpuInfo struct {
	UsageTotalPercent   float64     `json:"usage_total_percent"`
	UsagePerCorePercent []float64   `json:"usage_per_core_percent,omitempty"`
	IOWaitPercent       float64     `json:"iowait_percent,omitempty"`
	StealPercent        float64     `json:"steal_percent,omitempty"`
	CoresLogical        int         `json:"cores_logical,omitempty"`
	LoadAvg             loadAvgInfo `json:"loadavg,omitempty"`
	CtxSwitchesPerSec   float64     `json:"ctx_switches_per_sec,omitempty"`
	InterruptsPerSec    float64     `json:"interrupts_per_sec,omitempty"`
}

type loadAvgInfo struct {
	One     float64 `json:"1m"`
	Five    float64 `json:"5m"`
	Fifteen float64 `json:"15m"`
}

type memoryInfo struct {
	TotalMB     float64  `json:"total_mb,omitempty"`
	UsedMB      float64  `json:"used_mb,omitempty"`
	AvailableMB float64  `json:"available_mb,omitempty"`
	CachedMB    float64  `json:"cached_mb,omitempty"`
	BuffersMB   float64  `json:"buffers_mb,omitempty"`
	Swap        swapInfo `json:"swap,omitempty"`
	OMMKills    int64    `json:"oom_kills_total,omitempty"`
}

type swapInfo struct {
	TotalMB     float64 `json:"total_mb,omitempty"`
	UsedMB      float64 `json:"used_mb,omitempty"`
	UsedPercent float64 `json:"used_percent,omitempty"`
}

type diskInfo struct {
	Devices []diskDeviceInfo `json:"devices,omitempty"`
	FS      []diskFSInfo     `json:"fs,omitempty"`
}

type diskDeviceInfo struct {
	Name           string  `json:"name,omitempty"`
	ReadBps        int64   `json:"read_bps,omitempty"`
	WriteBps       int64   `json:"write_bps,omitempty"`
	ReadIops       float64 `json:"read_iops,omitempty"`
	WriteIops      float64 `json:"write_iops,omitempty"`
	ReadLatencyMs  float64 `json:"read_latency_ms,omitempty"`
	WriteLatencyMs float64 `json:"write_latency_ms,omitempty"`
	UtilPercent    float64 `json:"util_percent,omitempty"`
}

type diskFSInfo struct {
	Mount            string  `json:"mount,omitempty"`
	FSType           string  `json:"fstype,omitempty"`
	UsedPercent      float64 `json:"used_percent,omitempty"`
	TotalGB          float64 `json:"total_gb,omitempty"`
	FreeGB           float64 `json:"free_gb,omitempty"`
	InodeUsedPercent float64 `json:"inode_used_percent,omitempty"`
	Readonly         bool    `json:"readonly,omitempty"`
}

type networkInfo struct {
	Interfaces []networkInterfaceInfo `json:"interfaces,omitempty"`
}

type networkInterfaceInfo struct {
	Name     string  `json:"name,omitempty"`
	RxBps    int64   `json:"rx_bps,omitempty"`
	TxBps    int64   `json:"tx_bps,omitempty"`
	RxPps    float64 `json:"rx_pps,omitempty"`
	TxPps    float64 `json:"tx_pps,omitempty"`
	RxErrors uint64  `json:"rx_errors,omitempty"`
	TxErrors uint64  `json:"tx_errors,omitempty"`
	Dropped  uint64  `json:"dropped,omitempty"`
}

type processesInfo struct {
	Total   int `json:"total,omitempty"`
	Zombies int `json:"zombies,omitempty"`
}

type healthInfo struct {
	Status  string         `json:"status,omitempty"`
	Reasons []string       `json:"reasons,omitempty"`
	Scores  map[string]int `json:"scores,omitempty"`
}

type timeInfo struct {
	CollectedAtUnix    int64 `json:"collected_at_unix,omitempty"`
	AgentUptimeSeconds int64 `json:"agent_uptime_seconds,omitempty"`
}

var version = "dev"
var gitSHA = "unknown"
var buildTime = "unknown"

type fsUsage struct {
	Mount       string  `json:"mount"`
	UsedPercent float64 `json:"used_percent"`
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

	mux.HandleFunc("/metrics/extended", func(w http.ResponseWriter, r *http.Request) {
		if !authorized(r, *token) {
			w.WriteHeader(http.StatusUnauthorized)
			_, _ = w.Write([]byte("unauthorized"))
			return
		}

		payload, err := collectExtendedMetrics()
		if err != nil {
			log.Printf("collect extended metrics failed: %v", err)
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

	uptimeSec, err := readUptimeSeconds()
	if err != nil {
		return metricsPayload{}, err
	}

	swapUsage, err := readSwapUsage()
	if err != nil {
		return metricsPayload{}, err
	}

	diskReadBps, diskWriteBps, err := readDiskIO(1 * time.Second)
	if err != nil {
		return metricsPayload{}, err
	}

	netRxBps, netTxBps, err := readNetIO(1 * time.Second)
	if err != nil {
		return metricsPayload{}, err
	}

	fsUsage, err := readFSUsage()
	if err != nil {
		return metricsPayload{}, err
	}

	return metricsPayload{
		CPUUsage:     cpuUsage,
		MemoryUsage:  memUsage,
		DiskUsage:    diskUsage,
		LoadAvg:      loadAvg,
		AgentVersion: version,
		UptimeSec:    uptimeSec,
		SwapUsage:    swapUsage,
		DiskReadBps:  diskReadBps,
		DiskWriteBps: diskWriteBps,
		NetRxBps:     netRxBps,
		NetTxBps:     netTxBps,
		FSUsage:      fsUsage,
		CollectedAt:  time.Now().UTC().Format(time.RFC3339),
	}, nil
}

func collectExtendedMetrics() (extendedPayload, error) {
	base, err := collectMetrics()
	if err != nil {
		return extendedPayload{}, err
	}

	meta := metaInfo{
		SchemaVersion: 2,
		AgentBuild: buildInfo{
			GitSHA:    gitSHA,
			BuildTime: buildTime,
		},
		Capabilities: []string{
			"system",
			"cpu",
			"memory",
			"disk",
			"network",
			"processes",
			"health",
		},
	}

	system := readSystemInfo()

	cpuDetails, _ := readCPUExtended(150 * time.Millisecond)
	memDetails, _ := readMemoryInfo()
	diskDetails, _ := readDiskInfo()
	networkDetails, _ := readNetworkInfo(1 * time.Second)
	processDetails, _ := readProcessInfo()
	healthDetails := evaluateHealth(base, memDetails)

	timeDetails := timeInfo{
		CollectedAtUnix:    time.Now().UTC().Unix(),
		AgentUptimeSeconds: base.UptimeSec,
	}

	return extendedPayload{
		metricsPayload: base,
		Meta:           meta,
		System:         system,
		CPU:            cpuDetails,
		Memory:         memDetails,
		Disk:           diskDetails,
		Network:        networkDetails,
		Processes:      processDetails,
		Health:         healthDetails,
		Time:           timeDetails,
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

func readSwapUsage() (float64, error) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0, err
	}

	var total, free uint64
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		switch fields[0] {
		case "SwapTotal:":
			total, err = strconv.ParseUint(fields[1], 10, 64)
			if err != nil {
				return 0, err
			}
		case "SwapFree:":
			free, err = strconv.ParseUint(fields[1], 10, 64)
			if err != nil {
				return 0, err
			}
		}
		if total > 0 && free > 0 {
			break
		}
	}

	if total == 0 {
		return 0, nil
	}
	used := float64(total-free) / float64(total) * 100
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

func readDiskIO(interval time.Duration) (int64, int64, error) {
	readA, writeA, err := readDiskStats()
	if err != nil {
		return 0, 0, err
	}
	time.Sleep(interval)
	readB, writeB, err := readDiskStats()
	if err != nil {
		return 0, 0, err
	}
	readBps := int64(float64(readB-readA) / interval.Seconds())
	writeBps := int64(float64(writeB-writeA) / interval.Seconds())
	if readBps < 0 {
		readBps = 0
	}
	if writeBps < 0 {
		writeBps = 0
	}
	return readBps, writeBps, nil
}

func readDiskStats() (uint64, uint64, error) {
	data, err := os.ReadFile("/proc/diskstats")
	if err != nil {
		return 0, 0, err
	}

	var readBytes, writeBytes uint64
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 14 {
			continue
		}
		name := fields[2]
		if !isDiskDevice(name) {
			continue
		}
		readSectors, err := strconv.ParseUint(fields[5], 10, 64)
		if err != nil {
			return 0, 0, err
		}
		writeSectors, err := strconv.ParseUint(fields[9], 10, 64)
		if err != nil {
			return 0, 0, err
		}
		readBytes += readSectors * 512
		writeBytes += writeSectors * 512
	}
	return readBytes, writeBytes, nil
}

func isDiskDevice(name string) bool {
	if strings.HasPrefix(name, "sd") || strings.HasPrefix(name, "vd") || strings.HasPrefix(name, "nvme") || strings.HasPrefix(name, "mmcblk") {
		return true
	}
	return false
}

func readNetIO(interval time.Duration) (int64, int64, error) {
	rxA, txA, err := readNetStats()
	if err != nil {
		return 0, 0, err
	}
	time.Sleep(interval)
	rxB, txB, err := readNetStats()
	if err != nil {
		return 0, 0, err
	}
	rxBps := int64(float64(rxB-rxA) / interval.Seconds())
	txBps := int64(float64(txB-txA) / interval.Seconds())
	if rxBps < 0 {
		rxBps = 0
	}
	if txBps < 0 {
		txBps = 0
	}
	return rxBps, txBps, nil
}

func readNetStats() (uint64, uint64, error) {
	data, err := os.ReadFile("/proc/net/dev")
	if err != nil {
		return 0, 0, err
	}
	lines := strings.Split(string(data), "\n")
	var rxTotal, txTotal uint64
	for _, line := range lines {
		if !strings.Contains(line, ":") {
			continue
		}
		parts := strings.Split(line, ":")
		if len(parts) != 2 {
			continue
		}
		iface := strings.TrimSpace(parts[0])
		if iface == "lo" {
			continue
		}
		fields := strings.Fields(parts[1])
		if len(fields) < 16 {
			continue
		}
		rx, err := strconv.ParseUint(fields[0], 10, 64)
		if err != nil {
			return 0, 0, err
		}
		tx, err := strconv.ParseUint(fields[8], 10, 64)
		if err != nil {
			return 0, 0, err
		}
		rxTotal += rx
		txTotal += tx
	}
	return rxTotal, txTotal, nil
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

func readUptimeSeconds() (int64, error) {
	data, err := os.ReadFile("/proc/uptime")
	if err != nil {
		return 0, err
	}
	fields := strings.Fields(string(data))
	if len(fields) == 0 {
		return 0, fmt.Errorf("unexpected /proc/uptime format")
	}
	val, err := strconv.ParseFloat(fields[0], 64)
	if err != nil {
		return 0, err
	}
	return int64(val), nil
}

func readFSUsage() ([]fsUsage, error) {
	data, err := os.ReadFile("/proc/mounts")
	if err != nil {
		return nil, err
	}

	ignoreTypes := map[string]bool{
		"proc": true, "sysfs": true, "devtmpfs": true, "tmpfs": true, "cgroup": true,
		"cgroup2": true, "devpts": true, "overlay": true, "squashfs": true,
		"rpc_pipefs": true, "fusectl": true, "autofs": true,
	}

	var result []fsUsage
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 3 {
			continue
		}
		mount := fields[1]
		fsType := fields[2]
		if ignoreTypes[fsType] {
			continue
		}
		used, err := readDiskUsage(mount)
		if err != nil {
			continue
		}
		result = append(result, fsUsage{Mount: mount, UsedPercent: used})
	}

	if len(result) == 0 {
		return result, nil
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].UsedPercent > result[j].UsedPercent
	})
	if len(result) > 3 {
		result = result[:3]
	}
	return result, nil
}

type cpuStatSnapshot struct {
	CPUs map[string]cpuTimes
	Ctxt uint64
	Intr uint64
}

type cpuTimes struct {
	Idle   uint64
	Total  uint64
	IOWait uint64
	Steal  uint64
}

func readCPUExtended(delay time.Duration) (cpuInfo, error) {
	before, err := readCPUStatSnapshot()
	if err != nil {
		return cpuInfo{}, err
	}
	if delay > 0 {
		time.Sleep(delay)
	}
	after, err := readCPUStatSnapshot()
	if err != nil {
		return cpuInfo{}, err
	}

	totalUsage, perCore, iowait, steal := calcCPUUsage(before, after)
	load, _ := readLoadAvgInfo()
	ctxRate := calcRate(before.Ctxt, after.Ctxt, delay)
	intrRate := calcRate(before.Intr, after.Intr, delay)

	return cpuInfo{
		UsageTotalPercent:   totalUsage,
		UsagePerCorePercent: perCore,
		IOWaitPercent:       iowait,
		StealPercent:        steal,
		CoresLogical:        runtime.NumCPU(),
		LoadAvg:             load,
		CtxSwitchesPerSec:   ctxRate,
		InterruptsPerSec:    intrRate,
	}, nil
}

func readCPUStatSnapshot() (cpuStatSnapshot, error) {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return cpuStatSnapshot{}, err
	}

	cpums := make(map[string]cpuTimes)
	var ctxt uint64
	var intr uint64

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) == 0 {
			continue
		}
		if strings.HasPrefix(fields[0], "cpu") {
			if len(fields) < 5 {
				continue
			}
			var total uint64
			var parsed []uint64
			for _, v := range fields[1:] {
				val, err := strconv.ParseUint(v, 10, 64)
				if err != nil {
					return cpuStatSnapshot{}, err
				}
				total += val
				parsed = append(parsed, val)
			}
			idle := parsed[3]
			iowait := uint64(0)
			steal := uint64(0)
			if len(parsed) > 4 {
				iowait = parsed[4]
			}
			if len(parsed) > 7 {
				steal = parsed[7]
			}
			cpums[fields[0]] = cpuTimes{
				Idle:   idle,
				Total:  total,
				IOWait: iowait,
				Steal:  steal,
			}
			continue
		}
		if fields[0] == "ctxt" && len(fields) > 1 {
			val, _ := strconv.ParseUint(fields[1], 10, 64)
			ctxt = val
			continue
		}
		if fields[0] == "intr" && len(fields) > 1 {
			val, _ := strconv.ParseUint(fields[1], 10, 64)
			intr = val
			continue
		}
	}

	return cpuStatSnapshot{CPUs: cpums, Ctxt: ctxt, Intr: intr}, nil
}

func calcCPUUsage(before, after cpuStatSnapshot) (float64, []float64, float64, float64) {
	totalBefore, ok := before.CPUs["cpu"]
	if !ok {
		return 0, nil, 0, 0
	}
	totalAfter, ok := after.CPUs["cpu"]
	if !ok {
		return 0, nil, 0, 0
	}
	totalDiff := float64(totalAfter.Total - totalBefore.Total)
	idleDiff := float64(totalAfter.Idle - totalBefore.Idle)
	iowaitDiff := float64(totalAfter.IOWait - totalBefore.IOWait)
	stealDiff := float64(totalAfter.Steal - totalBefore.Steal)

	usage := percent(totalDiff-idleDiff, totalDiff)
	iowait := percent(iowaitDiff, totalDiff)
	steal := percent(stealDiff, totalDiff)

	var perCore []float64
	for name, afterTimes := range after.CPUs {
		if name == "cpu" {
			continue
		}
		beforeTimes, ok := before.CPUs[name]
		if !ok {
			continue
		}
		total := float64(afterTimes.Total - beforeTimes.Total)
		idle := float64(afterTimes.Idle - beforeTimes.Idle)
		perCore = append(perCore, percent(total-idle, total))
	}
	sort.Float64s(perCore)

	return usage, perCore, iowait, steal
}

func readLoadAvgInfo() (loadAvgInfo, error) {
	data, err := os.ReadFile("/proc/loadavg")
	if err != nil {
		return loadAvgInfo{}, err
	}
	fields := strings.Fields(string(data))
	if len(fields) < 3 {
		return loadAvgInfo{}, fmt.Errorf("unexpected /proc/loadavg format")
	}
	one, err := strconv.ParseFloat(fields[0], 64)
	if err != nil {
		return loadAvgInfo{}, err
	}
	five, err := strconv.ParseFloat(fields[1], 64)
	if err != nil {
		return loadAvgInfo{}, err
	}
	fifteen, err := strconv.ParseFloat(fields[2], 64)
	if err != nil {
		return loadAvgInfo{}, err
	}
	return loadAvgInfo{One: one, Five: five, Fifteen: fifteen}, nil
}

func readMemoryInfo() (memoryInfo, error) {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return memoryInfo{}, err
	}
	values := map[string]float64{}
	for _, line := range strings.Split(string(data), "\n") {
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}
		key := strings.TrimSuffix(fields[0], ":")
		val, err := strconv.ParseFloat(fields[1], 64)
		if err != nil {
			continue
		}
		values[key] = val
	}

	totalKB := values["MemTotal"]
	availableKB := values["MemAvailable"]
	cachedKB := values["Cached"]
	buffersKB := values["Buffers"]
	swapTotalKB := values["SwapTotal"]
	swapFreeKB := values["SwapFree"]
	usedKB := totalKB - availableKB
	swapUsedKB := swapTotalKB - swapFreeKB
	swapUsedPercent := percent(swapUsedKB, swapTotalKB)

	oomKills := readOOMKills()

	return memoryInfo{
		TotalMB:     totalKB / 1024.0,
		UsedMB:      usedKB / 1024.0,
		AvailableMB: availableKB / 1024.0,
		CachedMB:    cachedKB / 1024.0,
		BuffersMB:   buffersKB / 1024.0,
		Swap: swapInfo{
			TotalMB:     swapTotalKB / 1024.0,
			UsedMB:      swapUsedKB / 1024.0,
			UsedPercent: swapUsedPercent,
		},
		OMMKills: oomKills,
	}, nil
}

func readOOMKills() int64 {
	data, err := os.ReadFile("/proc/vmstat")
	if err != nil {
		return 0
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "oom_kill ") {
			fields := strings.Fields(line)
			if len(fields) == 2 {
				val, _ := strconv.ParseInt(fields[1], 10, 64)
				return val
			}
		}
	}
	return 0
}

func readDiskInfo() (diskInfo, error) {
	fs, err := readFSDetails()
	if err != nil {
		return diskInfo{}, err
	}
	return diskInfo{
		Devices: []diskDeviceInfo{},
		FS:      fs,
	}, nil
}

func readFSDetails() ([]diskFSInfo, error) {
	data, err := os.ReadFile("/proc/mounts")
	if err != nil {
		return nil, err
	}

	ignoreTypes := map[string]bool{
		"proc": true, "sysfs": true, "devtmpfs": true, "tmpfs": true, "cgroup": true,
		"cgroup2": true, "devpts": true, "overlay": true, "squashfs": true,
		"rpc_pipefs": true, "fusectl": true, "autofs": true,
	}

	var result []diskFSInfo
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) < 4 {
			continue
		}
		mount := fields[1]
		fsType := fields[2]
		options := fields[3]
		if ignoreTypes[fsType] {
			continue
		}

		stat := syscall.Statfs_t{}
		if err := syscall.Statfs(mount, &stat); err != nil {
			continue
		}
		totalBytes := float64(stat.Blocks) * float64(stat.Bsize)
		freeBytes := float64(stat.Bavail) * float64(stat.Bsize)
		usedBytes := totalBytes - freeBytes
		usedPercent := percent(usedBytes, totalBytes)
		inodeUsed := float64(stat.Files-stat.Ffree) / float64(max(stat.Files, 1)) * 100
		readonly := strings.Contains(options, "ro")

		result = append(result, diskFSInfo{
			Mount:            mount,
			FSType:           fsType,
			UsedPercent:      usedPercent,
			TotalGB:          totalBytes / (1024.0 * 1024.0 * 1024.0),
			FreeGB:           freeBytes / (1024.0 * 1024.0 * 1024.0),
			InodeUsedPercent: inodeUsed,
			Readonly:         readonly,
		})
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i].UsedPercent > result[j].UsedPercent
	})

	return result, nil
}

type netSnapshot struct {
	RxBytes   uint64
	TxBytes   uint64
	RxPackets uint64
	TxPackets uint64
	RxErrors  uint64
	TxErrors  uint64
	Dropped   uint64
}

func readNetworkInfo(delay time.Duration) (networkInfo, error) {
	before, err := readNetSnapshot()
	if err != nil {
		return networkInfo{}, err
	}
	if delay > 0 {
		time.Sleep(delay)
	}
	after, err := readNetSnapshot()
	if err != nil {
		return networkInfo{}, err
	}

	var interfaces []networkInterfaceInfo
	for name, afterStats := range after {
		beforeStats, ok := before[name]
		if !ok {
			continue
		}
		interval := delay.Seconds()
		rxBps := calcRateInt64(beforeStats.RxBytes, afterStats.RxBytes, interval)
		txBps := calcRateInt64(beforeStats.TxBytes, afterStats.TxBytes, interval)
		rxPps := calcRateFloat(beforeStats.RxPackets, afterStats.RxPackets, interval)
		txPps := calcRateFloat(beforeStats.TxPackets, afterStats.TxPackets, interval)

		interfaces = append(interfaces, networkInterfaceInfo{
			Name:     name,
			RxBps:    rxBps,
			TxBps:    txBps,
			RxPps:    rxPps,
			TxPps:    txPps,
			RxErrors: afterStats.RxErrors,
			TxErrors: afterStats.TxErrors,
			Dropped:  afterStats.Dropped,
		})
	}

	sort.Slice(interfaces, func(i, j int) bool {
		return interfaces[i].Name < interfaces[j].Name
	})

	return networkInfo{Interfaces: interfaces}, nil
}

func readNetSnapshot() (map[string]netSnapshot, error) {
	data, err := os.ReadFile("/proc/net/dev")
	if err != nil {
		return nil, err
	}
	lines := strings.Split(string(data), "\n")
	stats := make(map[string]netSnapshot)
	for _, line := range lines[2:] {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.Split(line, ":")
		if len(parts) != 2 {
			continue
		}
		iface := strings.TrimSpace(parts[0])
		fields := strings.Fields(strings.TrimSpace(parts[1]))
		if len(fields) < 16 {
			continue
		}
		rxBytes, _ := strconv.ParseUint(fields[0], 10, 64)
		rxPackets, _ := strconv.ParseUint(fields[1], 10, 64)
		rxErrs, _ := strconv.ParseUint(fields[2], 10, 64)
		rxDrop, _ := strconv.ParseUint(fields[3], 10, 64)
		txBytes, _ := strconv.ParseUint(fields[8], 10, 64)
		txPackets, _ := strconv.ParseUint(fields[9], 10, 64)
		txErrs, _ := strconv.ParseUint(fields[10], 10, 64)
		txDrop, _ := strconv.ParseUint(fields[11], 10, 64)

		stats[iface] = netSnapshot{
			RxBytes:   rxBytes,
			TxBytes:   txBytes,
			RxPackets: rxPackets,
			TxPackets: txPackets,
			RxErrors:  rxErrs,
			TxErrors:  txErrs,
			Dropped:   rxDrop + txDrop,
		}
	}
	return stats, nil
}

func readProcessInfo() (processesInfo, error) {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return processesInfo{}, err
	}
	total := 0
	zombies := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		if _, err := strconv.Atoi(entry.Name()); err != nil {
			continue
		}
		total++
		state, err := readProcessState(entry.Name())
		if err == nil && state == "Z" {
			zombies++
		}
	}
	return processesInfo{Total: total, Zombies: zombies}, nil
}

func readProcessState(pid string) (string, error) {
	data, err := os.ReadFile("/proc/" + pid + "/stat")
	if err != nil {
		return "", err
	}
	fields := strings.Fields(string(data))
	if len(fields) < 3 {
		return "", fmt.Errorf("unexpected /proc/%s/stat format", pid)
	}
	return fields[2], nil
}

func readSystemInfo() systemInfo {
	hostname, _ := os.Hostname()
	osInfo, _ := readOSRelease()
	kernel := readKernelVersion()
	bootTime := readBootTime()

	return systemInfo{
		Hostname: hostname,
		FQDN:     hostname,
		OS:       osInfo,
		Kernel:   kernel,
		Arch:     runtime.GOARCH,
		Virtualization: virtualizationInfo{
			Type: "unknown",
			Role: "guest",
		},
		BootTime: bootTime,
	}
}

func readOSRelease() (osInfo, error) {
	data, err := os.ReadFile("/etc/os-release")
	if err != nil {
		return osInfo{}, err
	}
	values := map[string]string{}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := parts[0]
		val := strings.Trim(parts[1], "\"")
		values[key] = val
	}
	return osInfo{
		Name:       values["ID"],
		Version:    values["VERSION_ID"],
		PrettyName: values["PRETTY_NAME"],
	}, nil
}

func readKernelVersion() string {
	var uts syscall.Utsname
	if err := syscall.Uname(&uts); err != nil {
		return ""
	}
	return charsToString(uts.Release[:])
}

func charsToString(chars []int8) string {
	var bytes []byte
	for _, c := range chars {
		if c == 0 {
			break
		}
		bytes = append(bytes, byte(c))
	}
	return string(bytes)
}

func readBootTime() string {
	data, err := os.ReadFile("/proc/stat")
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "btime ") {
			fields := strings.Fields(line)
			if len(fields) == 2 {
				sec, _ := strconv.ParseInt(fields[1], 10, 64)
				return time.Unix(sec, 0).UTC().Format(time.RFC3339)
			}
		}
	}
	return ""
}

func evaluateHealth(base metricsPayload, mem memoryInfo) healthInfo {
	status := "ok"
	reasons := []string{}
	scores := map[string]int{}

	if base.DiskUsage >= 90 {
		status = "warning"
		reasons = append(reasons, "disk usage >= 90%")
	} else if base.DiskUsage >= 80 {
		status = "warning"
		reasons = append(reasons, "disk usage >= 80%")
	}

	if base.MemoryUsage >= 90 {
		status = "warning"
		reasons = append(reasons, "memory usage >= 90%")
	} else if base.MemoryUsage >= 80 {
		status = "warning"
		reasons = append(reasons, "memory usage >= 80%")
	}

	scores["cpu"] = int(base.CPUUsage)
	scores["memory"] = int(base.MemoryUsage)
	scores["disk"] = int(base.DiskUsage)
	scores["network"] = 0

	return healthInfo{Status: status, Reasons: reasons, Scores: scores}
}

func calcRate(before, after uint64, delay time.Duration) float64 {
	interval := delay.Seconds()
	if interval <= 0 {
		return 0
	}
	return float64(after-before) / interval
}

func calcRateInt64(before, after uint64, interval float64) int64 {
	if interval <= 0 {
		return 0
	}
	return int64(float64(after-before) / interval)
}

func calcRateFloat(before, after uint64, interval float64) float64 {
	if interval <= 0 {
		return 0
	}
	return float64(after-before) / interval
}

func percent(part, total float64) float64 {
	if total <= 0 {
		return 0
	}
	return part / total * 100
}

func max(a, b uint64) uint64 {
	if a > b {
		return a
	}
	return b
}
