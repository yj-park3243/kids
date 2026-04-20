module.exports = {
  apps: [
    {
      name: 'kids-api',
      script: 'dist/main.js',
      watch: false,
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
      },
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      // 로그
      error_file: 'logs/api-error.log',
      out_file: 'logs/api-out.log',
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      merge_logs: true,
      // 재시작 정책
      max_restarts: 10,
      restart_delay: 1000,
      autorestart: true,
      // 메모리 제한 (초과 시 자동 재시작)
      max_memory_restart: '512M',
    },
  ],
};
