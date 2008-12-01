/*!
	@file SCCSVStringDictionaryFactory.h
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-08-19

 Copyright (c) 2007 Spectral Class
 
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 License available:  http://www.opensource.org/licenses/mit-license.html
 */
#if defined(__INTERNAL_SCCSVParser__)
#import "SCCSVFieldFactory.h"
#else
@protocol SCCSVFieldFactory;
#endif

/*!
	@class SCCSVStringDictionaryFactory
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-08-19

	A simple implementation of the SCCSVFieldFactory concrete protocol designed to demonstrate how a basic factory could be implemented to hook the output of the parser and compose it into a useful form.  It reads the CSV file into a user-provided mutable array as NSDictionary objects representing each record in the file.  The record fields are resolved using the column names as keys.  Note that the resultant data is sparse in so much as empty fields are not created so not ever dictionary will have all the keys which describe the data set.
 */
@interface SCCSVStringDictionaryFactory : NSObject <SCCSVFieldFactory>
{
	NSMutableArray *_recordKeys;
	NSMutableArray *_dataSet;
}

/*!
	@param dataSet The mutable array which will be populated with dictionaries representing the records int he incoming stream
	@return A newly initialized dictionary factory
	@brief the designated initializer for this factory class
 
	Creates a dictionary factory backed by the given dataSet.  Once the parser operation is complete, the records found will be placed in dataSet.
 */
- (id)initWithDataSetArray:(NSMutableArray *)dataSet;

/*!
	@return The array of keys (pulled from the CSV columns) which represent the superset of all keys present in the records read from the CSV file
 
	Note that this will be empty if the parse has not yet occurred.
 */
- (NSArray *)recordKeys;

@end
