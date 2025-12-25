module.exports = {
  apps: [
    {
      name: "app-name", // Change to your app name (e.g., "app-name")
      script: "dist/src/index.js", // Path to your output file (see above for how to get). Should be a compiled JS file.
      instances: "max", // "max" for all CPUs, or specify a number.
      exec_mode: "cluster", // Use "cluster" for zero-downtime reloads, "fork" for simple mode.
      watch: false, // Set true if you want PM2 to watch for file changes (dev only).
      max_memory_restart: "500M", // Restart if memory exceeds this amount.
      error_file: "./logs/err.log", // Error log file (create "./logs" dir if missing).
      out_file: "./logs/out.log",   // Out log file.
      log_file: "./logs/combined.log", // Combined log.
      time: true, // Add timestamp to logs.
      merge_logs: true, // Merge logs from all instances.
      autorestart: true, // Automatically restart on crash.
      max_restarts: 10, // Max restarts before giving up.
      min_uptime: "10s", // Consider "online" if alive for this time.
      env: {
        NODE_ENV: "production", // Default environment. (Set other secrets via env or .env or Secrets Manager.)
        // To inject secrets, use environment variables in your CI/CD, or add keys here.
        // E.g.: DATABASE_URL: "postgres://user:password@localhost:5432/db"
      },
      env_development: {
        NODE_ENV: "development",
        instances: 1,
        exec_mode: "fork",
      },
      node_args: "--expose-gc --trace-gc --trace-gc-ignore-scavenger", // Optional: Node.js runtime flags.
      kill_timeout: 5000, // Wait 5s before force-killing
      wait_ready: true, // Wait for app to send "ready" event (if supported).
      listen_timeout: 10000,
      shutdown_with_message: true, // Graceful shutdown (if supported).
    },
  ],
};

/**
 * PM2 ecosystem configuration file.
 * 
 * How to use:
 *   - Copy this file as `ecosystem.config.cjs` into your project root.
 *   - Edit the values as needed for your application.
 * 
 * Key fields:
 *   - `script`: Path to your main JS entry (after build). Set this to your transpiled/built server file.
 *     - If using TypeScript: after running `npm run build`, find your output (e.g., `dist/src/index.js` or `dist/main.js`).
 *     - Example: "dist/src/index.js"
 *   - `name`: Name of your app (shows up in `pm2 list`). Change to match your project.
 *   - `instances`: Set to `"max"` for all CPU cores. Use `1` for single process mode.
 *   - `exec_mode`: Use `"cluster"` for multiple processes, `"fork"` for single.
 *   - `error_file`, `out_file`, `log_file`: Relative/absolute paths for logs. Make sure the `./logs/` directory exists.
 *   - `env` & `env_development`: Environment variables for production and development.
 *       - `NODE_ENV` is used by most Node.js frameworks.
 *   - For more fields see: https://pm2.keymetrics.io/docs/usage/application-declaration/
 */
