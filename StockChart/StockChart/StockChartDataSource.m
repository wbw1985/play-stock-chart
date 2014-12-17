//
//  StockChartDataSource.m
//  StockChart
//
//  Created by Alison Clarke on 27/08/2014.
//
//  Copyright 2014 Scott Logic
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "StockChartDataSource.h"
#import "NSArray+StockChartUtils.h"

@implementation StockChartDataSource

- (instancetype)init {
  self = [super init];
  
  if (self) {
    self.chartData = [StockChartData getInstance];
  }
  
  return self;
}


#pragma mark Datasource Protocol Functions

// Returns the number of series in the specified chart
- (NSInteger)numberOfSeriesInSChart:(ShinobiChart *)chart {
  return 3;
}

// Returns the series at the specified index for a given chart
- (SChartSeries *)sChart:(ShinobiChart *)chart seriesAtIndex:(NSInteger)index {
  switch (index) {
    case 0:
      // Bollinger Band
      return [StockChartDataSource createBollingerBandSeries];
    case 1:
      // Volume
      return [StockChartDataSource createColumnSeries];
    case 2:
      // Candlestick
      return [StockChartDataSource createCandlestickSeries];
    default:
      return nil;
  }
}

// Returns the number of points for a specific series in the specified chart
- (NSInteger)sChart:(ShinobiChart *)chart numberOfDataPointsForSeriesAtIndex:(NSInteger)seriesIndex {
  // We have fewer data points for Bollinger bands
  if (seriesIndex == 0) {
    return [self.chartData numberOfDataPoints] - StockChartMovingAverageNPeriod;
  } else {
    return [self.chartData numberOfDataPoints];
  }
}

- (SChartAxis*)sChart:(ShinobiChart *)chart yAxisForSeriesAtIndex:(NSInteger)index {
  NSArray *allYAxes = [chart allYAxes];
  // The second series in the chart is our volume chart, which uses a different y axis. The other series use the default y axis
  if (index == 1) {
    return allYAxes[1];
  } else {
    return allYAxes[0];
  }
}

+ (SChartBandSeries*)createBollingerBandSeries {
  // Create a Band series
  SChartBandSeries *bandSeries = [SChartBandSeries new];
  
  bandSeries.crosshairEnabled = YES;
  bandSeries.title = @"Bollinger Band";
  bandSeries.crosshairEnabled = NO;
  bandSeries.style.lineColorHigh = [[ShinobiCharts theme] orangeColorLight];
  bandSeries.style.lineColorLow = [[ShinobiCharts theme] orangeColorLight];
  bandSeries.style.areaColorNormal = [[[ShinobiCharts theme] orangeColorDark] colorWithAlphaComponent:0.5];
  return bandSeries;
}

+ (SChartColumnSeries*)createColumnSeries {
  SChartColumnSeries *columnSeries = [SChartColumnSeries new];
  columnSeries.crosshairEnabled = YES;
  columnSeries.style.areaColor = [UIColor colorWithRed:0 green:0.4 blue:0.8 alpha:1];
  columnSeries.style.showAreaWithGradient = NO;
  return columnSeries;
}

+ (SChartCandlestickSeries*)createCandlestickSeries {
  // Create a candlestick series
  SChartCandlestickSeries *candlestickSeries = [SChartCandlestickSeries new];
  
  // Define the data field names
  NSArray *keys = @[@"Open",@"High", @"Low", @"Close"];
  candlestickSeries.dataSeries.yValueKeys = keys;
  candlestickSeries.crosshairEnabled = YES;
  
  return candlestickSeries;
}

// Returns the data point at the specified index for the given series/chart.
- (id<SChartData>)sChart:(ShinobiChart *)chart dataPointAtIndex:(NSInteger)dataIndex
        forSeriesAtIndex:(NSInteger)seriesIndex {
  switch (seriesIndex) {
    case 0:
      // Bollinger Band
      return [self bollingerDataPointAtIndex:dataIndex];
    case 1:
      // Volume
      return [self volumeDataPointAtIndex:dataIndex];
    case 2:
      // Candlestick
      return [self candlestickDataPointAtIndex:dataIndex];
    default:
      return nil;
  }
}

- (NSArray *)sChart:(ShinobiChart *)chart dataPointsForSeriesAtIndex:(NSInteger)seriesIndex {
  NSMutableArray *datapoints = [NSMutableArray array];
  NSUInteger noPoints = [self sChart:chart numberOfDataPointsForSeriesAtIndex:seriesIndex];
  
  switch (seriesIndex) {
    case 0:
      // Bollinger Band
      for (int i=0; i<noPoints; i++) {
        [datapoints addObject:[self bollingerDataPointAtIndex:i]];
      }
      break;
    case 1:
      // Volume
      for (int i=0; i<noPoints; i++) {
        [datapoints addObject:[self volumeDataPointAtIndex:i]];
      }
      break;
    case 2:
      // Candlestick
      for (int i=0; i<noPoints; i++) {
        [datapoints addObject:[self candlestickDataPointAtIndex:i]];
      }
      break;
    default:
      break;
  }
  
  if (datapoints.count == 0) {
    datapoints = nil;
  }
  
  return datapoints;
}

- (id<SChartData>)bollingerDataPointAtIndex:(NSUInteger)dataIndex {
  // Construct a data point to return
  SChartMultiYDataPoint *datapoint = [SChartMultiYDataPoint new];
  
  // We don't have bollinger data for the first StockChartMovingAverageNPeriod points of
  // the chartData, so we start at the StockChartMovingAverageNPeriod'th date
  datapoint.xValue = self.chartData.dates[dataIndex + StockChartMovingAverageNPeriod];
  
  // Make a dictionary of the different data points
  NSDictionary *bollingerData = @{ @"High": [self.chartData upperBollingerValueForIndex:dataIndex],
                                   @"Low": [self.chartData lowerBollingerValueForIndex:dataIndex] };
  datapoint.yValues = [bollingerData mutableCopy];
  return datapoint;
}

- (id<SChartData>)candlestickDataPointAtIndex:(NSUInteger)dataIndex {
  // Use a multi y datapoint
  SChartMultiYDataPoint *dp = [SChartMultiYDataPoint new];
  
  // Set the xValue (date)
  dp.xValue = self.chartData.dates[dataIndex];
  
  // Get the open, high, low, close values
  float openVal  = [self.chartData.seriesOpen[dataIndex] floatValue];
  float highVal  = [self.chartData.seriesHigh[dataIndex] floatValue];
  float lowVal   = [self.chartData.seriesLow[dataIndex] floatValue];
  float closeVal = [self.chartData.seriesClose[dataIndex] floatValue];
  
  // Make sure all values are > 0
  openVal  = MAX(openVal, 0);
  highVal  = MAX(highVal, 0);
  lowVal   = MAX(lowVal, 0);
  closeVal = MAX(closeVal, 0);
  
  // Set the OHLC values
  NSDictionary *ohlcData = @{@"Open": @(openVal),
                             @"High": @(highVal),
                             @"Low": @(lowVal),
                             @"Close": @(closeVal)};
  dp.yValues = [ohlcData mutableCopy];
  
  return dp;
}

- (id<SChartData>)volumeDataPointAtIndex: (NSUInteger)dataIndex {
  SChartDataPoint *dp = [SChartDataPoint new];
  dp.xValue = self.chartData.dates[dataIndex];
  dp.yValue = self.chartData.volume[dataIndex];
  return dp;
}

#pragma mark - StockChartDatasourceLookup methods
- (id)estimateYValueForXValue:(id)xValue forSeriesAtIndex:(NSUInteger)idx {
  if ([xValue isKindOfClass:[NSNumber class]]) {
    // Need it to be a date since we are comparing timestamp
    xValue = [NSDate dateWithTimeIntervalSince1970:[xValue doubleValue]];
  }
  NSUInteger index;
  @try {
    index = [self.chartData.dates indexOfBiggestObjectSmallerThan:xValue
                                                    inSortedRange:NSMakeRange(0, self.chartData.dates.count)];
  }
  @catch (NSException *exception) {
    index = 0;
  }
  
  SChartDataPoint *dp = [self sChart:nil dataPointAtIndex:index forSeriesAtIndex:idx];
  if ([dp isKindOfClass:[SChartMultiYDataPoint class]]) {
    NSDictionary *yValues = ((SChartMultiYDataPoint*)dp).yValues;
    if (yValues[@"Close"]) {
      return yValues[@"Close"];
    } else {
      return yValues[@"High"];
    }
  } else {
    return dp.yValue;
  }
}

@end