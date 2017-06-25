require 'cookieless_redis_store'
Rails.application.config.middleware.use CookielessRedisStore,
  redis: {database: 0}, expire_after: 1.month
