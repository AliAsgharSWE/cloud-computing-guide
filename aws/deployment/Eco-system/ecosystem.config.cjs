module.exports = {
    apps: [
      {
        name: "app-name",
        script: "dist/src/index.js",
        instances: "max",
        exec_mode: "cluster",
        watch: false,
        max_memory_restart: "500M",
        error_file: "./logs/err.log",
        out_file: "./logs/out.log",
        log_file: "./logs/combined.log",
        time: true,
        merge_logs: true,
        autorestart: true,
        max_restarts: 10,
        min_uptime: "10s",
        env: {
          NODE_ENV: "production",
        },
        env_development: {
          NODE_ENV: "development",
          instances: 1,
          exec_mode: "fork",
        },
        node_args: "--expose-gc --trace-gc --trace-gc-ignore-scavenger",
        kill_timeout: 5000,
        wait_ready: true,
        listen_timeout: 10000,
        shutdown_with_message: true,
      },
    ],
  };
  