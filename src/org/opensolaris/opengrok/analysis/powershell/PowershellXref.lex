/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").  
 * You may not use this file except in compliance with the License.
 *
 * See LICENSE.txt included in this distribution for the specific
 * language governing permissions and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at LICENSE.txt.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2017, Oracle and/or its affiliates. All rights reserved.
 * Portions Copyright (c) 2017, Chris Fraire <cfraire@me.com>.
 */

package org.opensolaris.opengrok.analysis.powershell;

import java.io.IOException;
import org.opensolaris.opengrok.analysis.JFlexXrefSimple;
import org.opensolaris.opengrok.web.HtmlConsts;
import org.opensolaris.opengrok.web.Util;
import java.util.Stack;
import java.util.regex.Pattern;
import java.util.regex.Matcher;
%%
%public
%class PoshXref
%extends JFlexXrefSimple
%unicode
%ignorecase
%int
%include CommonXref.lexh
%{
  private final Stack<String> styleStack = new Stack<String>();

  @Override
  public void reset() {
      super.reset();
      styleStack.clear();
  }

  // TODO move this into an include file when bug #16053 is fixed
  @Override
  protected int getLineNumber() { return yyline; }
  @Override
  protected void setLineNumber(int x) { yyline = x; }

  private Pattern GoToLabel = Pattern.compile("(break|continue)(\\s+)(\\w+)");

  private String getVariableName(String text) {
    String name = text;
    // Extract variable name from ${name} (complex variable)
    if (text.startsWith("${")) {
        name = text.substring(2,text.length()-1);
    } else {
        // Assuming extracting name from $name (simple variable)
        name = text.substring(1);
    }
    return name;
  }

  private void emitComplexVariable() throws IOException {
    String id = getVariableName(yytext());
    out.write("${");
    writeSymbol(id, Consts.poshkwd, yyline, false, true);
    out.write("}");
  }

  private void emitSimpleVariable() throws IOException {
    String id = getVariableName(yytext());
    out.write("$");
    writeSymbol(id, Consts.poshkwd, yyline, false, true);
  }

  @Override
  public void pushSpan(int newState, String className) throws IOException {
      super.pushSpan(newState, className);
      styleStack.push(className);
  }

  @Override
  public void yypop() throws IOException {
      super.yypop();
      styleStack.pop();

      if (!styleStack.empty()) {
          String style = styleStack.peek();
          disjointSpan(style);
      }
  }
%}

Identifier = [a-zA-Z_] [a-zA-Z0-9_-]*
SimpleVariable  = [\$] [a-zA-Z_] [a-zA-Z0-9_:-]*
ComplexVariable = [\$] "{" [^}]+  "}"
Operator = "-" [a-zA-Z]+
Label =  {WhspChar}* ":" {Identifier}
Break = "break" {WhiteSpace} {Identifier}
Continue = "continue" {WhiteSpace} {Identifier}
DataType = "[" [a-zA-Z_] [\[\]a-zA-Z0-9_.-]* "]"


/* The following should be matched by the 'Number' pattern below.
 * '\$ [0-9]+' :
 *     $1 $2 $10 ... (references to a regex match operation)
 *
 * '0[xX][0-9a-fA-F]+[lL]?' :
 *     0xA 0X12A 0x12L ... (hex values with optional 'L'ong data type)
 *
 * '(\.[0-9]+|[0-9]+(\.[0-9]*)?)' :
 *     .45 0.45 12. 34  ... (integers and real numbers)
 *
 * '([eE][+-]*[0-9]+)?' :  (optional exponential)
 *     e+12 in 32.e+12
 *     E-231 in 123.456E-231
 *
 *  '[dDlL]?' : (optional 'double' or 'long' data type designation)
 *     1.20d 1.23450e1d 1.2345e-1D
 *
 *  {MultiplierSuffix} : (optional multiplier suffix)
 *    kb, Kb, KB (kilobyte, 1024)
 *    mb, Mb, MB (megabyte, 1024 x 1024)
 *    gb, Gb, GB (gigabyte, 1024 x 1024 x 1024)
 *    tb, Tb, TB (terabyte, 1024 x 1024 x 1024 x 1024)
 *    pb, Pb, PB (petabyte, 1024 x 1024 x 1024 x 1024 x 1024)
 *
 *    1kb 1.30Dmb 0x10Gb 1.4e23Tb 0x12Lpb
 */
RegExGroup = \$ [0-9]+
MultiplierSuffix = ([kKmMgGtTp][bB])?
Number = {RegExGroup} | (0[xX][0-9a-fA-F]+[lL]?|(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][+-]*[0-9]+)?[dDlL]? ) {MultiplierSuffix}

/*Number = \$? [0-9]+\.[0-9]+|[0-9][0-9]*|"0x" [0-9a-fA-F]+*/

File = {FNameChar}+ "." ([a-zA-Z0-9]+)

/*
 * Differs from {FPath} in that the path segments are only constrained to be
 * {FNameChar}.
 */
AnyFPath = "/"? {FNameChar}+ ("/" {FNameChar}+)+

/*
 * States:
 * STRING   - double-quoted string, ex: "hello, world!"
 * QSTRING  - single-quoted string, ex: 'hello, world!'
 * COMMENT - multiple-line comment.
 * SCOMMENT - single-line comment, ex: # this is a comment
 * SUBSHELL - commands executed in a sub-shell,
 *               example 1: (echo $header; cat file.txt)
 * HERESTRING  - here-string, example: cat @" ... "@
 * HEREQSTRING - here-string, example: cat @' ... '@
 */
%state STRING COMMENT SCOMMENT QSTRING SUBSHELL HERESTRING HEREQSTRING

%include Common.lexh
%include CommonURI.lexh
%include CommonPath.lexh
%%

<STRING>{
 {SimpleVariable} | {ComplexVariable } {
    String id = yytext();
    out.write("<a href=\"");
    out.write(urlPrefix);
    out.write("refs=");
    out.write("&quot;" +id + "&quot;");
    appendProject();
    out.write("\">");
    out.write(id);
    out.write("</a>");
 }
}

<YYINITIAL>{
 \{     { incScope(); writeUnicodeChar(yycharat(0)); }
 \}     { decScope(); writeUnicodeChar(yycharat(0)); }
 \;     { endScope(); writeUnicodeChar(yycharat(0)); }
}

<YYINITIAL, SUBSHELL> {
 ^ {Label} { 
    out.write("<a class=\"xlbl\" name=\"");
    out.write(yytext().substring(1)); 
    out.write("\">");
    out.write(yytext()); 
    out.write("</a>");
 }
 {Break} | {Continue} {
    Matcher m = GoToLabel.matcher(yytext());
    String control="", space="", label="";
    if(m.find()) {
        control = m.group(1);
        space   = m.group(2);
        label   = m.group(3);
    }
    writeSymbol(control, Consts.poshkwd, yyline, false, false);
    out.write(space);
    out.write("<a class=\"d intelliWindow-symbol\" href=\"#");
    out.write(label);
    out.write("\" data-definition-place=\"defined-in-file\">");
    out.write(label);
    out.write("</a>");
 }
 {DataType} {
    String dataType = yytext();

    // strip off outer '[' and ']' and massage letter size
    String id = dataType.substring(1, dataType.length()-1).toLowerCase();
    
    // Check for array data type indicator ([]) and strip off
    int pos = id.indexOf("[]");
    if (pos != -1) {
        id = id.substring(0,pos);
    }
    // Dynamically add data type to constant
    // list so they do not turn into links.
    if (!Consts.poshkwd.contains(id)) {
        Consts.poshkwd.add(id);
    }
    out.write("[");
    writeSymbol(id, Consts.poshkwd, yyline, false, false);
    if (pos != -1) {
        out.write("[]");
    }
    out.write("]");
 }
 {ComplexVariable} {
    emitComplexVariable();
 }
 {SimpleVariable} {
    emitSimpleVariable();
 }
 {Identifier} | {Operator} {
    String id = yytext();
    
    /* Dynamically add cmdlet options (eg. -option) 
     * to keywords so they don't turn into links.
     */
    if (id.startsWith("-")) {
       String cmdletOption = id.toLowerCase();
       if (!Consts.poshkwd.contains(cmdletOption)) {
          Consts.poshkwd.add(cmdletOption);
       }
    }
    writeSymbol(id, Consts.poshkwd, yyline, false, false);
 }

 {Number}    {
    String lastClassName = getDisjointSpanClassName();
    disjointSpan(HtmlConsts.NUMBER_CLASS);
    out.write(yytext());
    disjointSpan(lastClassName);
 }

 \"    {
    pushSpan(STRING, HtmlConsts.STRING_CLASS);
    out.write(htmlize(yytext()));
 }
 \'    {
    pushSpan(QSTRING, HtmlConsts.STRING_CLASS);
    out.write(htmlize(yytext()));
 }

 \#    {
    pushSpan(SCOMMENT, HtmlConsts.COMMENT_CLASS);
    out.write(yytext());
 }
 \<\#    {
    pushSpan(COMMENT, HtmlConsts.COMMENT_CLASS);
    out.write(htmlize(yytext()));
 }

 \@\"    {
    pushSpan(HERESTRING, HtmlConsts.STRING_CLASS);
    out.write(htmlize(yytext()));
 }
 \@\'    {
    pushSpan(HEREQSTRING, HtmlConsts.STRING_CLASS);
    out.write(htmlize(yytext()));
 }
}

<STRING> {
 [`]\"    { out.write(htmlize(yytext())); }
 \"    {
    out.write(htmlize(yytext()));
    yypop();
 }
}

<QSTRING> {
 \'\'    { out.write(htmlize(yytext())); }
 \'    {
    out.write(htmlize(yytext()));
    yypop();
 }
}

<COMMENT> {
 \#\>    {
    out.write(htmlize(yytext()));
    yypop();
 }
}

<SCOMMENT> {
 {WhspChar}*{EOL}    {
    yypop();
    startNewLine();
 }
}

<SUBSHELL> {
  \)    {
    out.write(yytext());
    yypop();
  }
}

<HERESTRING> {
  // Match escaped dollar sign of variable 
  // (eg. `$var) so it does not turn into web-link.
   
  \` ({SimpleVariable} | {ComplexVariable}) { out.write(yytext()); }

  {SimpleVariable} {
     emitSimpleVariable();
  }

  {ComplexVariable} {
     emitComplexVariable();
  }
  ^ \"\@    {
    out.write(htmlize(yytext()));
    yypop();
  }
}

<HEREQSTRING> {
  ^ "'@"    {
    out.write(yytext());
    yypop();
  }
}

<YYINITIAL, SUBSHELL> {
  /* Don't enter new state if special character is escaped. */
  \\` | \\\( | \\\) | \\\\ | \\\{ |
  \\\" | \\' | \\\$ | \\\#    { out.write(htmlize(yytext())); }

  /* $# should not start a comment. */
  "$#" { out.write(yytext()); }

  \$ ? \( { pushSpan(SUBSHELL, null); out.write(yytext()); }
}

<YYINITIAL, SUBSHELL, STRING, SCOMMENT, QSTRING> {
    {File} {
        String path = yytext();
        out.write("<a href=\""+urlPrefix+"path=");
        out.write(path);
        appendProject();
        out.write("\">");
        out.write(path);
        out.write("</a>");
    }

    {AnyFPath}
            {out.write(Util.breadcrumbPath(urlPrefix+"path=",yytext(),'/'));}
}

<YYINITIAL, SUBSHELL, STRING, COMMENT, SCOMMENT, QSTRING, HERESTRING,
    HEREQSTRING> {
    [&<>\'\"]    { out.write(htmlize(yytext())); }
    {WhspChar}*{EOL}    { startNewLine(); }
    {WhiteSpace}   { out.write(yytext()); }
    [!-~]   { out.write(yycharat(0)); }
    [^\n]   { writeUnicodeChar(yycharat(0)); }
}

<STRING, SCOMMENT, QSTRING> {
{FNameChar}+ "@" {FNameChar}+ "." {FNameChar}+
        {
          writeEMailAddress(yytext());
        }
}

<STRING, SCOMMENT> {
    {BrowseableURI}    {
        appendLink(yytext(), true);
    }
}

<QSTRING> {
    {BrowseableURI}    {
        appendLink(yytext(), true, PoshUtils.STRINGLITERAL_APOS_DELIMITER);
    }
}

<COMMENT> {
    {BrowseableURI} \>?    {
        appendLink(yytext(), true, PoshUtils.MAYBE_END_MULTILINE_COMMENT);
    }
}
