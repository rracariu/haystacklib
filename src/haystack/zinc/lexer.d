// Written in the D programming language.
/**
Haystack Zinc token lexer

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.lexer;
import haystack.tag;
import haystack.zinc.util;
import std.ascii            : isLower, 
                              isUpper,
                              isAlpha,
                              isAlphaNum,
                              isDigit,
                              isControl,
                              isHexDigit,
                              isWhite;

/// Types of tokens that the lexer can provide
enum TokenType 
{ 
    id, 
    null_,
    marker,
    remove,
    na,
    bool_, 
    ref_, 
    str, 
    uri, 
    number, 
    date, 
    time, 
    dateTime, 
    coord, 
    xstr,
    empty = uint.max
}

/**
The result of a Lexer action.
*/
struct Token
{
    /**
    Create a token of a type and value
    */
    this(TokenType type, Tag tag)
    in (type != TokenType.empty, "Invalid token type")
    {
        this._type  = type;
        this.data   = tag;
    }

    /**
    Create a token of a non value type
    */
    this(TokenType type)
    in (type > TokenType.id && type < TokenType.bool_, "Invalid token type")
    {
        this._type  = type;
    }

    static Token makeChar(dchar c)
    {
        return Token(TokenType.empty, c);
    }

    // Create a char token
    private this(TokenType type, dchar c)
    in (type == TokenType.empty, "Invalid token type")
    {
        this._type  = TokenType.empty;
        this._chr   = c;
    }

    /**
    Current TokenType
    */
    @property TokenType type() pure const
    {
        return _type;
    }

    /**
    Token's tag data
    */
    @property ref const(Tag) tag() pure const
    {
        return data;
    }

    /**
    Get a Tag value from the token's data
    */
    const(T) value(T)() const
    in (isValid, "Can't get value from empty token.")
    {
        return  data.get!T;
    }

    @property dchar curChar() pure const
    in (type == TokenType.empty, "Invalid token type")
    {
        return _chr;
    }

    @property bool isValid() pure const
    {
        return type != TokenType.empty;
    }

    bool isOf(TokenType type, Tag value) const
    {
        return type == type &&  tag == value;
    }

    bool isId() pure const
    {
        return type == TokenType.id ;
    }

    bool hasChr(dchar c) pure const
    {
        return isEmpty && _chr == c;
    }

    @property bool isEmpty() pure const
    {
        return type == TokenType.empty;
    }

    @property bool isSpace() pure const
    {
        return !isNewLine && _chr.isWhite;
    }

    @property bool isNewLine() pure const
    {
        return isEmpty && _chr.isWhite && _chr.isControl;
    }

    @property bool isAlpha() pure const
    {
        return isEmpty && _chr.isAlpha;
    }

    @property bool isAlphaNum() pure const
    {
        return isEmpty && _chr.isAlphaNum;
    }

    @property bool isUpper() pure const
    {
        return isEmpty && _chr.isUpper;
    }

    bool isScalar() pure const
    {
        return type >= TokenType.null_
            && type <= TokenType.xstr;
    }

    bool opEquals()(auto ref const(Token) tk) const
    {
        // optimize non-value cases
        if (type == TokenType.empty)
            return tk.type == TokenType.empty;
        if (type == TokenType.null_)
            return tk.type == TokenType.null_;
        if (type == TokenType.marker)
            return tk.type == TokenType.marker;
        if (type == TokenType.remove)
            return tk.type == TokenType.remove;
        if (type == TokenType.na)
            return tk.type == TokenType.na;

        return type == tk.type && data == tk.data;
    }

private:
    TokenType _type = TokenType.empty;
    Tag data;
    dchar _chr;
}

/**
Lexes Zinc tokens from some char $(D InputRange)
*/
struct ZincLexer(Range) 
if (isCharInputRange!Range)
{
    this(Range r, int ver = 3)
    {
        this.input  = LookAhead!Range(r);
        this.ver    = ver;
        if (r.empty)
            isEmpty = true;
        else
            popFront();
    }

    @property bool empty() pure nothrow
    {
        return isEmpty;
    }

    @property ref const(Token) front() pure nothrow
    {
        return crtToken;
    }

    @property char cur()
    {
        return input.front;
    }

    void popFront()
    {
        if (input.hasStash)
            input.clearStash();

        if (input.empty)
        {
            isEmpty = true;
            return;
        }
        
        TokenType nextToken;
        char startChr = cur;
    
    loop:
        while (!input.empty)
        {
            switch (nextToken)
            {
                case TokenType.id:
                    if (lexId())
                        break loop;
                    nextToken = TokenType.null_;
                    continue loop;

                case TokenType.null_:
                    if (lexNull())
                        break loop;
                    nextToken = TokenType.marker;
                    continue loop;
                
                case TokenType.marker:
                    if (lexMarker())
                        break loop;
                    nextToken = TokenType.remove;
                    continue loop;

                case TokenType.remove:
                    if (lexRemove())
                        break loop;
                    nextToken = TokenType.na;
                    continue loop;

                case TokenType.na:
                    if (lexNa())
                        break loop;
                    nextToken = TokenType.bool_;
                    continue loop;

                case TokenType.bool_:
                    if (lexBool())
                        break loop;
                    nextToken = TokenType.ref_;
                    continue loop;

                case TokenType.ref_:
                    if (lexRef())
                        break loop;
                    nextToken = TokenType.str;
                    continue loop;

                case TokenType.str:
                    if (lexStr())
                        break loop;
                    nextToken = TokenType.uri;
                    continue loop;

                case TokenType.uri:
                    if (lexUri())
                        break loop;
                    nextToken = TokenType.number;
                    continue loop;

                case TokenType.number:
                    if (lexNumber())
                    {
                        if (input.crtStash.length <= 4) // verify if this isn't a date
                        {
                            if (lexDateTime() || lexTime())
                                break loop;
                        }
                        break loop;
                    }
                    else
                    {
                        nextToken = TokenType.dateTime;
                        continue loop;
                    }

                case TokenType.dateTime: // the date part can be parsed here, so try both
                    if (lexDateTime())
                        break loop;
                    nextToken = TokenType.time;
                    continue loop;
                    
                case TokenType.time:
                    if (lexTime())
                        break loop;
                    nextToken = TokenType.coord;
                    continue loop;

                case TokenType.coord:
                    if (lexCoord())
                        break loop;
                    nextToken = TokenType.xstr;
                    continue loop;

                case TokenType.xstr:
                    if (ver < 3 && lexBin())
                        break loop;
                    else if (lexXStr())
                        break loop;
                     goto default;

                default:
                    if (!input.empty && cur == '\r') // normalize nl
                    {
                        input.popFront();
                        startChr = cur;
                        continue loop;
                    }
                    crtToken = Token.makeChar(startChr);
                    if (input.hasStash)
                        return input.save();
                    if (!input.empty)
                        input.popFront();
                    break loop;
            }
        }
    }

    @property ref Range range() scope return
    {
        return input.range;
    }
    
    @property void range(scope ref Range r)
    {
        input.range     = r;
        crtToken        = Token.makeChar(r.front);
    }

    // zinc spec version
    int ver = 3;

    // internals
package(haystack):
    
    @disable this();
    @disable this(this);

    @property ref buffer() scope return
    {
        return input;
    }

    bool isEmpty = false;

    bool lexId()
    {
        enum State { fistChar, restChars }
    loop:
        for (State crtState; !input.empty; input.popFront())
        {
            final switch (crtState)
            {
                case State.fistChar: // required to start with lower case alpha
                    if (!cur.isLower)
                        return false;
                    input.stash();
                    crtState++;
                    continue;

                case State.restChars:
                    if (isXStrChar)
                        input.stash();
                    else
                        break loop;
            }
        }
        crtToken = Token(TokenType.id, input.commitStash().tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("abcAbcD123_wwwe", Token(TokenType.id, "abcAbcD123_wwwe".tag));
        assertTokenValue("idFoo@", Token(TokenType.id, "idFoo".tag));
        assertTokenValue("idBar ", Token(TokenType.id, "idBar".tag));
        assertTokenValue("someId,", Token(TokenType.id, "someId".tag));
        // bad
        assertTokenEmpty("BAD%Id");
    }

    bool lexNull()
    {
        if (cur != 'N')
            return false;
        
        // probe if this has more
        input.stash();
        input.popFront();
        if (!input.empty && isXStrChar)
        {
            input.save(); // save look ahead
            return false;
        }

        crtToken = Token(TokenType.null_, Tag());
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("N", Token(TokenType.null_));
        assertTokenValue("N ", Token(TokenType.null_));
        assertTokenValue("N,", Token(TokenType.null_));
        // bad
        assertTokenEmpty("X");
        assertTokenEmpty("Nx");
    }

    bool lexMarker()
    {
        if (cur != 'M')
            return false;
        
        input.stash();
        input.popFront();
        if (!input.empty && isXStrChar)
        {
            input.save;
            return false;
        }
        
        crtToken = Token(TokenType.marker, marker());
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("M", Token(TokenType.marker));
        assertTokenValue("M ", Token(TokenType.marker));
        assertTokenValue("M|", Token(TokenType.marker));
        // bad
        assertTokenEmpty("Y");
    }

    bool lexRemove()
    {
        if (cur != 'R')
            return false;
        
        input.stash();
        input.popFront();
        if (!input.empty && isXStrChar)
        {
            input.save;
            return false;
        }

        crtToken = Token(TokenType.remove, Tag.init);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("R", Token(TokenType.remove));
        assertTokenValue("R ", Token(TokenType.remove));
        assertTokenValue("R,", Token(TokenType.remove));
        // bad
        assertTokenEmpty("K");
    }

    bool lexNa()
    {
        if (cur != 'N')
            return false;
        
        input.stash();
        input.popFront();
        input.stash();
        if (cur != 'A')
        {
            // more to lex
            input.popFront();
            input.save();
            return false;
        }

        if (!input.empty)
        {
            input.popFront();
            if (!input.empty && isXStrChar)
            {
                input.stash();
                input.save;
                return false;
            }
        }
        crtToken = Token(TokenType.na, Na().Tag);
        return true;
    }
    unittest
    {   
        // good
        assertTokenValue("NA", Token(TokenType.na));
        assertTokenValue("NA ", Token(TokenType.na));
        assertTokenValue("NA,", Token(TokenType.na));
        // bad
        assertTokenEmpty("NAM,");
        assertTokenEmpty("XY");
    }

    bool lexBool()
    {
        if (cur != 'T' && cur != 'F')
            return false;
        
        const val = (cur == 'T');
            
        input.stash();
        input.popFront();
        if (!input.empty && isXStrChar)
        {
            input.save;
            return false;
        }

        crtToken = Token(TokenType.bool_, val.tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("T", Token(TokenType.bool_, true.tag));
        assertTokenValue("T\t", Token(TokenType.bool_, true.tag));
        assertTokenValue("F", Token(TokenType.bool_, false.tag));
        assertTokenValue("F,", Token(TokenType.bool_, false.tag));
        // bad
        assertTokenEmpty("K");
    }

    bool lexRef()
    {
        if (cur != '@')
            return false;

        string val;
        string dis;

        for (input.popFront(); !input.empty; input.popFront())
        {
            if (cur.isAlphaNum
                || cur == '_' 
                || cur == ':' 
                || cur == '-' 
                || cur == '.' 
                || cur == '~')
            {
                input.stash();
            }
            else if ((cur.isWhite && !cur.isControl) && input.hasStash)
            {
                input.popFront(); // skip ws
                val = input.commitStash();
                if (lexStr())
                {
                    dis = crtToken.value!Str;
                    crtToken = Token();
                }
                else
                {
                    input.save();
                }
                break;
            }
            else if (input.hasStash)
            {
                break;
            }
            else
            {
                return false;
            }
        }
        if (val is null)
        {
            if (!input.hasStash)
                return false;
            val = input.commitStash();
        }
        crtToken = Token(TokenType.ref_, Tag(Ref(val, dis)));
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("@fooBar,", Token(TokenType.ref_, Ref("fooBar").Tag));
        assertTokenValue(`@fooBar "a nice description"`, Token(TokenType.ref_, Ref("fooBar", "a nice description").Tag));
        assertTokenValue(`@fooBar ,`, Token(TokenType.ref_, Ref("fooBar").Tag));
        // bad
        assertTokenEmpty("@");
        assertTokenEmpty("&");
        assertTokenEmpty("@#");
    }

    string lexChars(immutable char[] esc, immutable char[] escVal, char delim = '"')
    in (esc.length == escVal.length)
    {
        import std.format   : formattedRead;
        import std.string   : indexOf;

        if (cur != delim)
            return null;
        
        bool hasTerm = false;
        for (input.popFront(); !input.empty; input.popFront())
        {
        loop:
            if (cur == delim) // found terminator
            {
                hasTerm = true;
                input.popFront();
                break;
            }

            if (cur < ' ')
                return null;
            
            if (cur != '\\')
            {
                input.stash();
            }
            else
            {
                if (input.empty)
                    return null;

                input.popFront();
                if (cur == 'u')
                {
                    if (input.empty)
                        return null;
                    input.popFront();
                    if (input.empty || !cur.isHexDigit)
                        return null;
                    dchar unicodeChar; 
                    int count = input.formattedRead("%x", &unicodeChar);
                    if (!count)
                        return null;
                    input.stash(unicodeChar);
                    // we consumed all u's chars, no need to popFront
                    goto loop; 
                }
                ptrdiff_t escPos = esc.indexOf(cur);
                if (escPos != -1)
                    input.stash(escVal[escPos]);
                else
                    return null;
            }
        }
        if (!hasTerm)
            return null;
        if (!input.hasStash)
            return "";
        return input.commitStash();
    }

    bool lexStr()
    {
        enum delim                  = '"';
        static immutable strEsc     = [ 'n', 'r', 't', '"', '\\', '$', 'b', 'f'];
        static immutable strEscVal  = ['\n', '\r', '\t', '"', '\\', '$', '\b', '\f'];
        
        string chars = lexChars(strEsc, strEscVal, delim);
        if (chars is null)
            return false;
        
        crtToken = Token(TokenType.str, chars.tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue(`"hello world"`, Token(TokenType.str, "hello world".tag));
        assertTokenValue(`"a line\nsome\ttab"`, Token(TokenType.str, "a line\nsome\ttab".tag));
        assertTokenValue(`""`, Token(TokenType.str, "".tag));
        assertTokenValue(`"some unicode char: \u00E6"`, Token(TokenType.str, "some unicode char: æ".tag));
        assertTokenValue(`"inline unicode char: 語"`, Token(TokenType.str, "inline unicode char: 語".tag));
        // bad
        assertTokenEmpty(`"`);
        assertTokenEmpty(`"fooo`);
        assertTokenEmpty(`"a bad \u"`);
    }

    bool lexUri()
    {
        enum delim = '`';
        static immutable uriEsc = [':', '/', '?', '#', '[', ']', '@', '`', '\\', '&', '=', ';'];
        static immutable uriEscVal = [':', '/', '?', '#', '[', ']', '@', '`', '\\', '&', '=', ';'];
        string chars = lexChars(uriEsc, uriEscVal, delim);
        if (chars !is null)
        {
            crtToken = Token(TokenType.uri, cast(Tag) Uri(chars));
            return true;
        }
        return false;
    }
    unittest
    {
        // good
        assertTokenValue("`/a/b/c`", Token(TokenType.uri, cast(Tag) Uri("/a/b/c")));
        // bad
        assertTokenEmpty("`");
    }

    bool lexNumber()
    {
        import std.math : isNaN;
        enum State { integral, fractionalDigit, fractional, expSign, exp, unit }
        
        // test the optional sign
        if (cur == '-')
        {
            input.stash();
            input.popFront();
            if (input.empty)
                return false;
            if (!cur.isDigit && input.find("INF"))
            {
                crtToken = Token(TokenType.number, tag(-1 * double.infinity));
                return true;
            }
        }
        // lex number parts
        if (cur.isDigit)
        {
            static void parseNum(const(char)[] chars, ref double val)
            {
                import std.format : formattedRead;
                chars.formattedRead("%g", &val);
            }

            bool isUnit()
            {
                return cur.isAlpha || cur == '%' || cur == '_' || cur == '/' || cur == '$' || cur > 127;
            }

            double value;
            string unit;
            State crtState = State.integral;
            input.stash();
        loop:
            for (input.popFront(); !input.empty; input.popFront())
            {
                final switch (crtState)
                {
                    case State.integral:
                        if (cur.isDigit)
                        {
                            input.stash();
                        }
                        else if (cur == '_')
                        {
                            continue;
                        }
                        else if (cur == '.')
                        {
                            input.stash();
                            crtState = State.fractionalDigit;
                        }
                        else if (isUnit)
                        {
                            parseNum(input.crtStash, value);
                            input.clearStash();
                            input.stash();
                            crtState = State.unit;
                        }
                        else
                        {
                            // save current scratch buffer and try matching for date or time
                            if (input.crtStash.length == 4 && cur == '-'
                                    || input.crtStash.length == 2 && cur == ':')
                                input.save();
                            break loop;
                        }
                        break;

                    case State.fractionalDigit:
                        if (cur.isDigit)
                        {
                            input.stash();
                            crtState = State.fractional;
                        }
                        else
                        {
                            return false;
                        }
                        break;

                    case State.fractional:
                        if (cur.isDigit)
                        {
                            input.stash();
                        }
                        else if (cur == '_')
                        {
                            continue;
                        }
                        else if (cur == 'e' || cur == 'E')
                        {    
                            input.stash();
                            crtState = State.expSign;
                        }
                        else if (isUnit)
                        {
                            parseNum(input.crtStash, value);
                            input.clearStash();
                            input.stash();
                            crtState = State.unit;
                        }
                        else
                        {   
                            // nothing to process
                            break loop;
                        }
                        break;

                    case State.expSign:
                        if (cur == '+' || cur == '-' || cur.isDigit)
                        {
                            input.stash();
                            crtState = State.exp;
                        }
                        else
                        {
                            return false;
                        }
                        break;

                    case State.exp:
                        if (cur.isDigit)
                        {
                            input.stash();
                        }
                        else if (isUnit)
                        {
                            parseNum(input.crtStash, value);
                            input.clearStash();
                            input.stash();
                            crtState = State.unit;
                        }
                        else
                        {
                            // nothing to process
                            break loop;
                        }
                        break;

                    case State.unit:
                        if (isUnit)
                        {
                            input.stash();
                        }
                        else
                        {
                            // nothing to process
                            break loop;
                        }
                        break;
                }
            }

            if (value.isNaN)
                parseNum(input.crtStash, value);
            else
                unit = input.commitStash();

            crtToken = Token(TokenType.number, Num(value, unit).Tag);
            return true;
        }
        else if (input.find("INF"))
        {
            crtToken = Token(TokenType.number, tag(double.infinity));
            return true;
        }
        else if (input.crtStash == "Na")
        {
            input.clearStash();
            if (input.empty)
                return false;

            if (cur == 'N')
            {
                input.popFront();
                crtToken = Token(TokenType.number, tag(double.nan));
                return true;
            }
        }
        return false;
    }
    unittest
    {
        assertTokenValue("-INF", Token(TokenType.number, (-1 * double.infinity).tag));
        assertTokenValue("INF", Token(TokenType.number, (double.infinity).tag));
        assertTokenIsNan("NaN");
        assertTokenIsNan("NaN,");
        assertTokenValue("100", Token(TokenType.number, 100.tag));
        assertTokenValue("-88", Token(TokenType.number, (-88).tag));
        assertTokenValue("-99.", Token(TokenType.number, (-99.0).tag));
        assertTokenValue("42.42", Token(TokenType.number, (42.42).tag));
        assertTokenValue("9.6e+10", Token(TokenType.number, (96000000000).tag));
        assertTokenValue("100%", Token(TokenType.number, Num(100, "%").Tag));
        assertTokenValue("100$", Token(TokenType.number, Num(100, "$").Tag));
        // bad
        assertTokenEmpty("-");
        assertTokenEmpty("Na");
        assertTokenEmpty("IN");
        assertTokenEmpty("_12");
    }

    bool lexDate()
    {
        import std.conv : to;
        enum State { year, month, day }

        State crtState;
        int year, month, day;
        int parts = 0;
        
        for (; !input.empty && parts < 8; input.popFront())
        {
            final switch (crtState)
            {
                case State.year:
                    if (cur.isDigit)
                    {
                        input.stash();
                        if (++parts > 4) // to many digits
                            return false;
                    }
                    else if (cur == '-' && parts == 4)
                    {
                        year = to!int(input.crtStash());
                        input.clearStash();
                        crtState++;
                    }
                    else if (parts > 0) // keep the stashed digits
                    {
                        input.save();
                        return false;
                    }
                    else // no match
                    {
                        return false;
                    }
                    break;

                case State.month:
                    if (cur.isDigit)
                    {
                        input.stash();
                        if (++parts > 6)
                            return false;
                    }
                    else if (cur == '-' && parts == 6)
                    {
                        month = to!int(input.crtStash());
                        input.clearStash();
                        crtState++;
                    }
                    else
                    {
                        return false;
                    }
                    break;

                case State.day:
                    if (!cur.isDigit)
                        return false;
                    
                    input.stash();
                    if (++parts == 8)
                    {
                        day = to!int(input.crtStash());
                        input.clearStash();
                    }
                    break;
            }
        }
        if (crtState < State.day)
            return false;
        crtToken = Token(TokenType.date, Date(year, month, day).Tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("2017-01-15", Token(TokenType.date, Date(2017, 01, 15).Tag));
        assertTokenValue("2900-12-31", Token(TokenType.date, Date(2900, 12, 31).Tag));
        assertTokenValue("2900-12-31234", Token(TokenType.date, Date(2900, 12, 31).Tag));
        // bad
        assertTokenValue("200017-111-22", Token(TokenType.number, 200017.tag));
        assertTokenValue("2-1-2", Token(TokenType.number, 2.tag));
        assertTokenValue("2017_1-2", Token(TokenType.number, 20171.tag));
    }

    bool lexTime()
    {
        import std.conv : to;
        enum State { hours, minutes, sec, dot, fraction }
        
        State crtState;
        int hours, minutes, sec, fraction;
        int parts = 0;

        if (input.empty)
            return false;

    loop:
        for (; !input.empty; input.popFront())
        {
            final switch (crtState)
            {
                case State.hours:
                    if (cur.isDigit) // check the 2nd digit of the hours number
                    {
                        input.stash();
                        if (++parts > 2)
                            return false;
                    }
                    else if (cur == ':' && parts == 2) // got the 2 hour numbers and sep
                    {
                        hours = to!int(input.crtStash());
                        input.clearStash();
                        crtState++;
                    }
                    // no separator found
                    else
                    {
                        return false;
                    }
                    break;

                case State.minutes:
                    if (cur.isDigit)
                    {
                        input.stash();
                        if (++parts > 4)
                            return false;
                    }
                    else if (cur == ':' && parts == 4)
                    {
                        minutes = to!int(input.crtStash());
                        input.clearStash();
                        crtState++;
                    }
                    else
                    {
                        return false; // no separator found
                    }
                    break;

                case State.sec:
                    if (cur.isDigit)
                    {
                        input.stash();
                        parts++;
                    }
                    else
                    {
                        return false;
                    }
                    
                    if (parts == 6)
                    {
                        sec = to!int(input.crtStash());
                        input.clearStash();
                        crtState++;
                    }
                    break;

                case State.dot:
                    if (cur != '.')
                        break loop;
                    crtState++;
                    break;

                case State.fraction:
                    if (cur.isDigit)
                    {
                        input.stash();
                        parts++;
                    }
                    else
                    {
                        if (!input.hasStash)
                            return false;
                        break loop;
                    }
                    break;
            }
        }
        if (parts < 6)
            return false;
        if (crtState == State.fraction && input.hasStash)
        {
            fraction = to!int(input.crtStash());
            input.clearStash();
        }
        crtToken = Token(TokenType.date, Time(hours, minutes, sec, fraction).Tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("09:40:03", Token(TokenType.date, Time(9, 40, 3).Tag));
        assertTokenValue("23:59:59", Token(TokenType.date, Time(23, 59, 59).Tag));
        assertTokenValue("23:59:59.999", Token(TokenType.date, Time(23, 59, 59, 999).Tag));
        // bad
        assertTokenValue("7000:00", Token(TokenType.number, 7000.tag));
        assertTokenValue("8:00", Token(TokenType.number, 8.tag));
        assertTokenValue("05:12", Token(TokenType.number, 5.tag));
        assertTokenValue("23:", Token(TokenType.number, 23.tag));
    }

    // used for both Date and DateTime lexing
    bool lexDateTime()
    {
        import core.time    : msecs;
        import std.datetime : UTC;
        import haystack.zinc.tzdata : timeZone;

        if (!lexDate()) // try the date part
            return false;
        if (input.empty || cur != 'T') // got only the date part
            return true;
        
        Tag date = crtToken.data;

        input.clearStash(); // clear the date stash
        input.popFront(); // move next
        crtToken = Token();
        if (input.empty) // it must have more
            return false;

        if (!lexTime()) // get the time part
            return false;
            
        if (input.empty)
            return false;
            
        Tag time    = crtToken.data;
        input.clearStash(); // clear the time stash
        crtToken = Token();

        enum State {utc, hours, minutes, tz}
            
        int tkCount = 0;
        string offset;
    loop:
        for (State crtState; !input.empty; input.popFront())
        {
            final switch (crtState)
            {
                case State.utc:
                    if (cur == 'Z') // end of utc date time
                    {
                        if (input.empty)
                            break loop; // done
                        crtState = State.tz;
                        continue; // parse the UTC tz name
                    }
                    else if (cur == '-' || cur == '+') // offset
                    {
                        input.stash();
                        crtState = State.hours;
                    }
                    else
                    {
                        return false;
                    }
                    break;

                case State.hours:
                    if (cur.isDigit) // offset hours
                    {
                        input.stash();
                        tkCount++;
                        continue;
                    }
                    else if (tkCount < 2) // must be number
                    {
                        return false;
                    }
                    if (cur == ':' && tkCount == 2) // got 2 numbers and a separator
                    {
                        input.stash();
                        tkCount     = 0;
                        crtState    = State.minutes;
                        continue;
                    }
                    // no separator found
                    if (tkCount > 2)
                        return false;
                    break;

                case State.minutes:
                    if (cur.isDigit) // minutes number
                    {
                        input.stash();
                        if (++tkCount == 2) // found the minutes number
                        {
                            offset      = input.commitStash();
                            tkCount     = 0;
                            crtState    = State.tz;
                        }
                        continue;
                    }
                    else if (tkCount < 2) // must be number
                    {
                        return false;
                    }
                    break;

                case State.tz:
                    if (tkCount == 0)
                    {
                        if (cur == ' ')
                        {
                            tkCount++;
                            continue;
                        }
                        else
                        {
                            break loop;
                        }
                    }
                            
                    if (tkCount == 1) // ensure tz starts with an alpha
                    {
                        if (cur.isAlpha)
                        {
                            input.stash();
                            tkCount++;
                            continue;
                        }
                        else
                        {
                            return false; // invalid tz start
                        }
                    }
                    else if (cur.isAlpha 
                                || cur == '/' 
                                || cur == '_' 
                                || cur == '-' 
                                || cur == '+' ) // the rest of tz chars
                    {
                        input.stash();
                    }
                    else // found all
                    {
                        break loop;
                    }

                    break;
            }
        }

        string tzName = input.commitStash();
        DateTime dt = DateTime(date.get!Date, time.get!Time);
            
        if (tzName.empty || tzName == "UTC")
        {
            crtToken = Token(TokenType.dateTime, SysTime(dt, msecs((time.get!Time).millis), UTC()).Tag);
        }
        else
        {
            try
            {
                auto tz = timeZone(tzName);
                crtToken = Token(TokenType.dateTime, SysTime(dt, tz).Tag);
            }
            catch(Exception e)
            {
                import std.conv         : to;
                import std.algorithm    : filter;
                import std.string       : indexOf;
                immutable gmtTz = "Etc/GMT" ~ offset[0..offset.indexOf(':')].filter!(c => c != '0').to!string();
                auto tz = timeZone(gmtTz);
                crtToken = Token(TokenType.dateTime, SysTime(dt, tz).Tag);
            }
        }
        return true; // done        
    }
    unittest
    {
        import core.time : msecs;
        import std.datetime : TimeZone, UTC;

        // good
        assertTokenValue("2017-01-17T13:51:20Z", Token(TokenType.dateTime, SysTime(DateTime(2017, 1, 17, 13, 51, 20), UTC()).Tag));
        assertTokenValue("2009-11-09T15:39:00Z", Token(TokenType.dateTime, SysTime(DateTime(2009, 11, 9, 15, 39, 0), UTC()).Tag));
        assertTokenValue("1989-12-21T15:39:00Z UTC", Token(TokenType.dateTime, SysTime(DateTime(1989, 12, 21, 15, 39, 0), UTC()).Tag));
        assertTokenValue("2015-03-31T18:06:41.956Z", Token(TokenType.dateTime, SysTime(DateTime(2015, 3, 31, 18, 6, 41), msecs(956), UTC()).Tag));
        
        import haystack.zinc.tzdata;
        assertTokenValue("2010-08-31T08:45:00+02:00 Europe/Athens", Token(TokenType.dateTime, SysTime(DateTime(2010, 8, 31, 8, 45, 0), timeZone("Europe/Athens")).Tag));
        assertTokenValue("2010-08-31T08:45:00-05:00 New_York", Token(TokenType.dateTime, SysTime(DateTime(2010, 8, 31, 8, 45, 0), timeZone("New_York")).Tag));
        assertTokenValue("2010-08-31T08:45:00+02:00 Nicosia", Token(TokenType.dateTime, SysTime(DateTime(2010, 8, 31, 8, 45, 0), timeZone("Asia/Nicosia")).Tag));
        // bad
        assertTokenEmpty("2009-11-09T");
        assertTokenEmpty("2009-11-09T4");
    }

    bool lexCoord()
    {
        double lat, lng;
        enum State { coord, paran, lat, lng, done }
        State state;

        loop:
        for (; !input.empty; input.popFront())
        {
            final switch (state)
            {
                case State.coord:
                    if (cur != 'C')
                        return false;
                    
                    input.stash();
                    state = State.paran;
                    continue;

                case State.paran:
                    if (cur != '(')
                        return false;
                    
                    input.stash();
                    state = State.lat;
                    continue;
                   
                case State.lat:
                    if (!cur.isDigit && cur != '-')
                        return false;

                    input.clearStash();
                    
                    if (!lexNumber())
                        return false;
                    if (cur != ',')
                        return false;
                    
                    lat = crtToken.data.val!Num;
                    input.clearStash();
                    state = State.lng;
                    continue;

                case State.lng:
                    if (!lexNumber())
                        return false;
                    if (cur != ')')
                        return false;
                    lng = crtToken.data.val!Num;
                    state = State.done;
                    continue;

                case State.done:
                    break loop;
            }
        }
        if (state != State.done)
            return false;
        crtToken = Token(TokenType.coord, Coord(lat, lng).Tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("C(37.545826,-77.449188), ", Token(TokenType.coord, Coord(37.545826,-77.449188).Tag));
        // bad
        assertTokenEmpty(`C`);
        assertTokenEmpty(`C()`);
        assertTokenEmpty(`C(42.3)`);
        assertTokenEmpty(`C(42.3,)`);
    }

    bool lexXStr()
    {
        enum State { firstChar, restChars, enc, done }
        
        State crtState;
        string type;
        string data;

        loop:
        for(; !input.empty; input.popFront())
        {
            final switch (crtState)
            {
                case State.firstChar:
                    if (!cur.isUpper)
                        return false;

                    input.stash();
                    crtState    = State.restChars;
                    break;

                case State.restChars:
                    if (cur.isAlphaNum || cur == '_')
                    {
                        input.stash();
                        continue;
                    }

                    if (cur != '(')
                        return false;
                    
                    type        = input.commitStash();
                    crtState    = State.enc;
                    break;

                case State.enc:
                    if (!lexStr()) // consumes the string
                        return false;
                    data = crtToken.data.get!Str;
                    crtToken = Token();
                    // check next char
                    if (!input.empty && cur == ')')
                    {
                        crtState    = State.done;
                        continue;
                    }
                    else
                    {
                        return false;
                    }
                    
                case State.done:
                    break loop;
            }
        }
        if (crtState != State.done)
            return false;
        crtToken = Token(TokenType.xstr, XStr(type, data).Tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue(`FooBar("alabala")`, Token(TokenType.xstr, XStr("FooBar", "alabala").Tag));
        assertTokenValue(`Massive("\n")`, Token(TokenType.xstr, XStr("Massive", "\n").Tag));
        assertTokenValue(`Bin("mimeType"),`, Token(TokenType.xstr, XStr("Bin", "mimeType").Tag));
        // bad
        assertTokenEmpty(`Xx(")`);
        assertTokenEmpty(`Yx(""`);
    }

    // lexer for legacy Bin tag
    bool lexBin()
    {
        enum State { bin, mime, done }
        State state;

        loop:
        for(; !input.empty; input.popFront())
        {
            final switch (state)
            {
                case State.bin:
                    if (!input.find("Bin(", true))
                       return false;

                    if (cur == '"') // found possible XStr
                    {
                        input.save();
                        return false;
                    }
                    input.clearStash();
                    input.stash();
                    state   = State.mime;
                    break;

                case State.mime:
                    if (cur != ')')
                    {
                        input.stash();
                        continue;
                    }
                    state   = State.done;
                    break loop;

                case State.done:
                    assert(false);
            }
        }
        if (state != State.done)
            return false;
        string data = input.commitStash();
        crtToken = Token(TokenType.xstr, XStr("Bin", data).Tag);
        return true;
    }
    unittest
    {
        assertTokenValue(`Bin(text/plain),`, Token(TokenType.xstr, XStr("Bin", "text/plain").Tag), 2);
        assertTokenEmpty(`Bad(text/plain),`, 2);
    }

private:

    // test for a posible XStr part
    @property bool isXStrChar()
    {
        return cur.isAlphaNum || cur == '_';
    }

    // The current decoded token
    Token crtToken;
    // The look-ahead range
    LookAhead!Range input = void;
}
/// a string based lexer
alias ZincStringLexer = ZincLexer!string;
// bootstraps the rest of the lexer's unit tests
unittest
{
    auto l = ZincStringLexer("");
}
// test if provided string data decodes to the provided Token value
private void assertTokenValue(string data, Token value, int ver = 3)
{
    auto lex    = ZincStringLexer(data, ver);
    assert(lex.front() == value, "Failed expecting: " ~ value.tag.toStr ~ " got: " ~ lex.front().tag.toStr);
}

// test if provided string data decodes to the provided Token type
private void assertTokenType(string data, TokenType value, int ver = 3)
{
    auto lex    = ZincStringLexer(data, ver);
    assert(lex.front().type == value);
}

// test if provided string data decodes to the provided Token value
private void assertTokenIsNan(string data, int ver = 3)
{
    auto lex    = ZincStringLexer(data, ver);
    assert(lex.front().data.get!Num.isNaN);
}
// test if the provided string data can not be decoded
private void assertTokenEmpty(string data, int ver = 3)
{
    auto lex    = ZincStringLexer(data, ver);
    assert(lex.front().isEmpty);
}

package void dumpLexer(Lexer)(auto ref Lexer lex)
{
    import std.algorithm    : move;
    import std.stdio        : writeln;
    import std.conv         : to;
    foreach (ref tk; lex.move())
    {
        writeln("Token type: ", tk.type, ", value: ", tk.type != TokenType.empty ? tk.tag.toStr() : "'" ~ to!string(tk.curChar) ~ "'");
    }
}