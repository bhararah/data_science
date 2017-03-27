library(dplyr)
library(ggplot2)
library(reshape2)
library(h2o)

setClass('myDate')
setAs('character', 'myDate', function(from) as.Date(from, format = '%Y-%m-%d'))

casual <- read.csv('D:\\hour.csv', colClasses = c('date' = 'myDate'),
                   col.names = c('id', 'date', 'season', 'yr_2012', 'month', 'hour',
                                 'holiday', 'day_week', 'workday', 'weather',
                                 'temperature_41', 'temperature_50', 'humidity_100', 'windspeed_67',
                                 'nr_casual', 'nr_registered', 'nr_total'))[,c(2:11,13:15)]
registered <- read.csv('D:\\hour.csv', colClasses = c('date' = 'myDate'),
                       col.names = c('id', 'date', 'season', 'yr_2012', 'month', 'hour',
                                     'holiday', 'day_week', 'workday', 'weather',
                                     'temperature_41', 'temperature_50', 'humidity_100', 'windspeed_67',
                                     'nr_casual', 'nr_registered', 'nr_total'))[,c(2:11,13,14,16)]
total <- read.csv('D:\\hour.csv', colClasses = c('date' = 'myDate'),
                  col.names = c('id', 'date', 'season', 'yr_2012', 'month', 'hour',
                                'holiday', 'day_week', 'workday', 'weather',
                                'temperature_41', 'temperature_50', 'humidity_100', 'windspeed_67',
                                'nr_casual', 'nr_registered', 'nr_total'))[,c(2:11,13,14,17)]

colnames(casual)[colnames(casual)=='nr_casual'] <- 'nr'
colnames(registered)[colnames(registered)=='nr_registered'] <- 'nr'
colnames(total)[colnames(total)=='nr_total'] <- 'nr'

plot(total$season)
plot(total$holiday)
plot(total$day_week)
plot(total$workday)
plot(total$weather)
plot(total$temperature_41)
plot(total$humidity_100)
plot(total$windspeed_67)

train <- total
train <- subset(train, weather < 4)
train <- subset(train, temperature_41 > 0.2 & temperature_41 < 0.8)
train <- subset(train, humidity_100 > 0.3 & humidity_100 < 0.9)
train <- subset(train, windspeed_67 > 0.0 & windspeed_67 < 0.4)

train$holiday <- NULL
casual$holiday <- NULL
registered$holiday <- NULL
total$holiday <- NULL

summary(train)
sapply(train, function(x) sum(is.na(x)))
sapply(train, function(x) sum(x<0, na.rm=TRUE))

train %>% melt(id.vars = "yr_2012") %>% tbl_df %>%
  ggplot() + geom_histogram(aes(x = value+0.000, fill = as.factor(yr_2012))) +
  facet_wrap(~ variable, scales = "free") #+ scale_x_log10()

ggplot(train) + geom_histogram(aes(x = nr+0.000)) +
  facet_grid(season~., scales = "free") #+ scale_x_log10()

ggplot(train) + geom_histogram(aes(x = nr+0.000)) +
  facet_grid(yr_2012~., scales = "free") #+ scale_x_log10()

ggplot(train) + geom_histogram(aes(x = nr+0.000)) +
  facet_grid(month~., scales = "free") #+ scale_x_log10()

ggplot(train) + geom_histogram(aes(x = nr+0.000)) +
  facet_grid(hour~., scales = "free") #+ scale_x_log10()

ggplot(train) + geom_histogram(aes(x = nr+0.000)) +
  facet_grid(day_week~., scales = "free") #+ scale_x_log10()

ggplot(train) + geom_histogram(aes(x = nr+0.000)) +
  facet_grid(workday~., scales = "free") #+ scale_x_log10()

ggplot(train) + geom_histogram(aes(x = nr+0.000)) +
  facet_grid(weather~., scales = "free") #+ scale_x_log10()

train %>% group_by(day_week, workday) %>% summarize(n = n()) %>%
  mutate(pc = n/sum(n)*100)

train %>% filter(nr>250) %>%
  group_by(month, hour) %>% summarize(n = n()) %>%
  mutate(pc = n/sum(n)*100) %>% as.data.frame()

train %>% filter(nr>400) %>%
  group_by(workday) %>% summarize(n = n()) %>%
  mutate(pc = n/sum(n)*100)

train %>% group_by(season) %>% 
  summarize(max = max(nr))

train %>% filter(windspeed_67>0.3 & humidity_100<0.5) %>%
  select(month, nr)

#idx_1 <- sample(1:nrow(train), nrow(train)*0.2)
#idx_2 <- sample(base::setdiff(1:nrow(train), idx_1), nrow(train)*0.2)
#idx_3 <- sample(base::setdiff(1:nrow(train), c(idx_1,idx_2)), nrow(train)*0.2)
#idx_4 <- sample(base::setdiff(1:nrow(train), c(idx_1,idx_2,idx_3)), nrow(train)*0.2)
#idx_5 <- sample(base::setdiff(1:nrow(train), c(idx_1,idx_2,idx_3,idx_4)), nrow(train)*0.2)

#t1 <- train[idx_1,]
#t2 <- train[idx_2,]
#t3 <- train[idx_3,]
#t4 <- train[idx_4,]
#t5 <- train[idx_5,]
#rm(idx_1,idx_2,idx_3,idx_4,idx_5)

h2o.init(max_mem_size = '8g', nthreads = -1)

splits <- h2o.splitFrame(as.h2o(train), ratios = 0.6)

rf_g <- h2o.grid('randomForest', x = 1:11, y = 12, nfolds = 3, 
                 training_frame = splits[[1]], validation_frame = splits[[2]], 
                 hyper_params = list(ntrees = c(10, 50, 100), 
                                     max_depth = c(10, 20, 50), 
                                     nbins = c(10, 20, 50)))
h2o.getGrid(rf_g@grid_id, 'mse')

gbm_g <- h2o.grid('gbm', x = 1:11, y = 12, nfolds = 3, 
                  training_frame = splits[[1]], validation_frame = splits[[2]], 
                  hyper_params = list(ntrees = c(10, 50, 100), 
                                      max_depth = c(10, 20, 50), 
                                      nbins = c(10, 20, 50), 
                                      learn_rate = c(0.02, 0.2)))
h2o.getGrid(gbm_g@grid_id, 'mse')

glm_g <- h2o.grid('glm', x = 1:11, y = 12, nfolds = 3, 
                  training_frame = splits[[1]], validation_frame = splits[[2]], 
                  hyper_params = list(alpha = c(0.1, 0.5, 1)))
glm_1 <- h2o.glm(x = 1:11, y = 12, nfolds = 3, 
                 training_frame = splits[[1]], 
                 validation_frame = splits[[2]])
glm_2 <- h2o.glm(x = 1:11, y = 12, nfolds = 3, 
                 training_frame = splits[[1]], 
                 validation_frame = splits[[2]], 
                 family = 'poisson')
glm_3 <- h2o.glm(x = 1:11, y = 12, nfolds = 3, 
                 training_frame = splits[[1]], 
                 validation_frame = splits[[2]], 
                 family = 'gamma')
glm_4 <- h2o.glm(x = 1:11, y = 12, nfolds = 3, 
                 training_frame = splits[[1]], 
                 validation_frame = splits[[2]], 
                 family = 'tweedie')

dl_g <- h2o.grid('deeplearning', x = 1:11, y = 12, nfolds = 3, 
                 training_frame = splits[[1]], validation_frame = splits[[2]], 
                 hyper_params = list(activation = c('Tanh', 
                                                    'TanhWithDropout', 
                                                    'Rectifier', 
                                                    'RectifierWithDropout', 
                                                    'Maxout', 
                                                    'MaxoutWithDropout')))
h2o.getGrid(dl_g@grid_id, 'mse')

h2o.performance(h2o.getModel(rf_g@model_ids[[1]]), as.h2o(total))
h2o.performance(h2o.getModel(gbm_g@model_ids[[1]]), as.h2o(total))
h2o.performance(h2o.getModel(glm_g@model_ids[[1]]), as.h2o(total))
h2o.performance(glm_1, as.h2o(total))
h2o.performance(glm_2, as.h2o(total))
h2o.performance(glm_3, as.h2o(total))
h2o.performance(glm_4, as.h2o(total))
h2o.performance(h2o.getModel(dl_g@model_ids[[1]]), as.h2o(total))

h2o.performance(h2o.getModel(rf_g@model_ids[[1]]), as.h2o(casual))
h2o.performance(h2o.getModel(gbm_g@model_ids[[1]]), as.h2o(casual))
h2o.performance(h2o.getModel(glm_g@model_ids[[1]]), as.h2o(casual))
h2o.performance(glm_1, as.h2o(casual))
h2o.performance(glm_2, as.h2o(casual))
h2o.performance(glm_3, as.h2o(casual))
h2o.performance(glm_4, as.h2o(casual))
h2o.performance(h2o.getModel(dl_g@model_ids[[1]]), as.h2o(casual))

h2o.performance(h2o.getModel(rf_g@model_ids[[1]]), as.h2o(registered))
h2o.performance(h2o.getModel(gbm_g@model_ids[[1]]), as.h2o(registered))
h2o.performance(h2o.getModel(glm_g@model_ids[[1]]), as.h2o(registered))
h2o.performance(glm_1, as.h2o(registered))
h2o.performance(glm_2, as.h2o(registered))
h2o.performance(glm_3, as.h2o(registered))
h2o.performance(glm_4, as.h2o(registered))
h2o.performance(h2o.getModel(dl_g@model_ids[[1]]), as.h2o(registered))

h2o.shutdown(prompt = FALSE)