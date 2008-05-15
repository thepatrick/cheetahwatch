/*!
	@file SCCSVFieldFactory.h
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-08-19

 Copyright (c) 2007 Spectral Class
 
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 License available:  http://www.opensource.org/licenses/mit-license.html
 */
@class SCCSVParseMachine;

/*!
	@protocol SCCSVFieldFactory
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-08-19

	The concrete protocol which must be implemented by objects used as factories for the CSV parser.
 */
@protocol SCCSVFieldFactory

/*!
	@param parser The parsing maching making the callback
 
	Called once at the beginning of a parse job being performed by the parser so that the factory can initialize internal state, etc
 */
- (void)parserStartDocument:(SCCSVParseMachine *)parser;

/*!
	@param parser The parsing maching making the callback
 
	Called once at the end of a parse job perfromed by the parser so that the factory can shut down, write back data, etc
 */
- (void)parserEndDocument:(SCCSVParseMachine *)parser;

/*!
	@param parser The parsing maching making the callback
	@return An opaque token which will be passed back to the factory whenever the record is to be manipulated
 
	Called by the parser when it encounters the beginning of a new record in the input stream.  Allows the factory to create any new meta-data structures to back the information which is about to be read.
 */
- (NSObject *)parserBuildNewRecord:(SCCSVParseMachine *)parser;

/*!
	@param parser The parsing maching making the callback
	@param rawValue The key read from the column for field at index
	@return an opaque, non-nil key which will be passed back to the factory whenever the parser reads data in this column

	Called by the parser when it encounters a column heading in the beginning of the document so that the factory knows which key should be applied to the fields under it
 */
- (NSObject *)parser:(SCCSVParseMachine *)parser buildRecordKey:(NSString *)rawValue;

/*!
	@param parser The parsing maching making the callback
	@param rawValue The string read for the field
	@param recordKey The key created by buildRecordKey: which resolves this field in the recordToken record
	@param recordToken The opaque token representing the record into which this field should be stored
 
	Called by the parser to ask the factory to populate the field for recordKey in recordToken with the data in rawValue
 */
- (void)parser:(SCCSVParseMachine *)parser populateField:(NSString *)rawValue forRecordKey:(NSObject *)recordKey inRecord:(NSObject *)recordToken;

/*!
	@param parser The parsing maching making the callback
	@param record The record which is now complete and will no longer be written into by the parser
 
	Called when the parser is finished parsing one record
 */
- (void)parser:(SCCSVParseMachine *)parser closeRecord:(NSObject *)record;

/*!
	@param parser The parsing maching making the callback
	@param errorMsg The message produced by the parser when an error is encountered
 
	Called by the parser when a fatal error is encountered during a parse operation
 */
- (void)parser:(SCCSVParseMachine *)parser fatalErrorRaised:(NSString *)errorMsg;

@end
