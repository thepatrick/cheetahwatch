/*!
	@file SCCSVXMLFactory.h
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-09-05

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
	@class SCCSVXMLFactory
	@author jmdisher (Copyright 2007 Spectral Class. All rights reserved.)
	@date 2007-09-05

	A simple implementation of the SCCSVFieldFactory concrete protocol which demonstrates how CSV data can be converted into sparse XML data.  This can be re-used and the xmlDocument is replaced at the end of every successful parse with the document representing the most recent document completely parsed.
 */
@interface SCCSVXMLFactory : NSObject <SCCSVFieldFactory>
{
	NSXMLElement *_list;
	NSXMLElement *_record;
	NSXMLDocument *_document;
}

/*!
	@return The XML document which contains the entire XML tree of the data found during the most recently parsed document
 
	This is the way that external code gets access to the data harvested by this factory.  Once the parse has completed, call this method to get the tree for output or later analysis.
 */
- (NSXMLDocument *)xmlDocument;

@end
