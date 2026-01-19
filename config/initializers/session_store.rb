Rails.application.config.session_store :cookie_store,
                                       key: "_stackscope_session",
                                       expire_after: 7.days
