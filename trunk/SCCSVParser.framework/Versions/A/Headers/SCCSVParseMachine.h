/*!
	@file SCCSVParseMachine.h
 
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-08-10

 Copyright (c) 2007 Spectral Class
 
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
 
 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 License available:  http://www.opensource.org/licenses/mit-license.html
 */
@protocol SCCSVFieldFactory;
@class SCCSVMachineState;

/*!
	@class SCCSVParseMachine
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-08-10

	The machine facade which encapsulates all the complexity in the underlying parser.  A factory implementing the SCCSVFieldFactory concrete protocol is required to actually use the machine since it contains the logic that this general-purpose parser will call out to so that the user-code can do what is required with the data in its situation.
 */
@interface SCCSVParseMachine : NSObject
{
	NSDictionary *_states;
	
	NSMutableArray *_recordKeys;
	
	int _currentFieldIndex;
	int _currentRecordIndex;
	NSMutableString *_currentField;
	NSObject *_currentRecord;
	int _errorCharacterIndex;
	BOOL _isParsingHeader;
	BOOL _errorRaised;
	NSObject<SCCSVFieldFactory> *_factory;
}

/*!
	@param stream The NSInputStream from which the data will be read for the parse operation (note that the calling code is responsible for opening and closing the stream)
	@param factory The SCCSVFieldFactory concrete protocol implementation which will receive the callbacks from the parsing machine as the stream is read
 
	Once one has a valid factory, this is the only method to interact with the parser.  This method will synchronously read the stream, sending callbacks to the factory when externally useful events occur (fields being read, records being completed, errors, etc), and returning once the stream is exhausted (run to EOF).
 */
- (void)parseStream:(NSInputStream *)stream withFieldFactory:(NSObject<SCCSVFieldFactory> *)factory;

@end
