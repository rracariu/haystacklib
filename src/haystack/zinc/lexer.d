// Written in the D programming language.
/**
Haystack zinc lexer.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.lexer;
import haystack.tag;
import haystack.zinc.util;
import std.ascii            : isLower, isUpper, isAlpha, isAlphaNum, isDigit, isHexDigit;
import std.range.primitives : isInputRange, ElementEncodingType;
import std.traits           : isSomeChar;
///////////////////////////////////////////////////////////////////
//
// Zinc token lexer
//
///////////////////////////////////////////////////////////////////

/// Types of tokens that the lexer can provide
enum TokenType { id, null_, marker, remove, na, bool_, ref_, str, uri, number, date, time, dateTime, coord, xstr, none = uint.max }

/**
The result of a Lexer action.
*/
struct Token
{
    TokenType type = TokenType.none;

    @property ref const(Tag) tag() const
    {
        return data;
    }

    const(T) value(T)() const
    {
        assert (type != TokenType.none);
        return  data.get!T;
    }

    @property dchar chr() const pure
    {
        assert (type == TokenType.none);
        return _chr;
    }

    @property bool isValid() const pure
    {
        return type != TokenType.none;
    }

    bool isOf(TokenType type, Tag value) const
    {
        return type == type &&  tag == value;
    }

    bool isId() pure const
    {
        return type == TokenType.id ;
    }

    bool hasChr(dchar c) const pure
    {
        return type == TokenType.none && _chr == c;
    }

    @property bool isChar() const pure
    {
        return type == TokenType.none;
    }

    @property bool isWs() const pure
    {
        return hasChr(' ') || hasChr('\t');
    }

    @property bool isNl() const pure
    {
        return hasChr('\n');
    }

    bool isScalar() const pure
    {
        return type == TokenType.null_
            || type == TokenType.marker
            || type == TokenType.remove
            || type == TokenType.na
            || type == TokenType.bool_
            || type == TokenType.ref_
            || type == TokenType.str
            || type == TokenType.uri
            || type == TokenType.number
            || type == TokenType.date
            || type == TokenType.time
            || type == TokenType.dateTime
            || type == TokenType.coord
            || type == TokenType.xstr;
    }

    bool opEquals()(auto ref const(Token) tk) const
    {
        // optimize non-value cases
        if (type == TokenType.none)
            return tk.type == TokenType.none;
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
    Tag data;
    dchar _chr;
}

/**
Lexes Zinc tokens from some char $(D InputRange)
**/
struct ZincLexer(Range) 
if (isInputRange!Range && isSomeChar!(ElementEncodingType!Range))
{
    this(Range r, int ver = 3)
    {
        this.input  = LookAhead!Range(r);
        this.ver    = ver;
        // set head of this range
        if (!r.empty)
            popFront();
        else
            isEmpty = true;
    }

    @property bool empty()
    {
        return isEmpty;
    }

    @property ref const(Token) front()
    {
        return crtToken;
    }

    @property char cur()
    {
        return input.front;
    }

    void popFront()
    {
        if (input.empty)
        {
            isEmpty = true;
            return;
        }
        TokenType tryToken;
        char startChr = cur;
    loop:
        while (!input.empty)
        {
            switch (tryToken)
            {
                case TokenType.id:
                    mixin(lexInstruction("Id", TokenType.null_.stringof));
                case TokenType.null_:
                    mixin(lexInstruction("Null", TokenType.marker.stringof));
                case TokenType.marker:
                    mixin(lexInstruction("Marker", TokenType.remove.stringof));
                case TokenType.remove:
                    mixin(lexInstruction("Remove", TokenType.na.stringof));
                case TokenType.na:
                    mixin(lexInstruction("Na", TokenType.bool_.stringof));
                case TokenType.bool_:
                    mixin(lexInstruction("Bool", TokenType.ref_.stringof));
                case TokenType.ref_:
                    mixin(lexInstruction("Ref", TokenType.str.stringof));
                case TokenType.str:
                    mixin(lexInstruction("Str", TokenType.uri.stringof));
                case TokenType.uri:
                    mixin(lexInstruction("Uri", TokenType.number.stringof));
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
                        tryToken = TokenType.dateTime;
                        continue loop;
                    }
                case TokenType.dateTime: // the date part can be parsed here, so try both
                    mixin(lexInstruction("DateTime", TokenType.time.stringof));
                case TokenType.time:
                    mixin(lexInstruction("Time", TokenType.coord.stringof));
                case TokenType.coord:
                    mixin(lexInstruction("Coord", TokenType.xstr.stringof));
                case TokenType.xstr:
                    if (ver < 3 && lexBin())
                        break loop;
                    if (lexXStr())
                        break loop;
                     goto default;
                default:
                    if (!input.empty && cur == '\r') // normalize nl
                    {
                        input.popFront();
                        startChr = cur;
                        continue loop;
                    }
                    crtToken = Token(TokenType.none);
                    crtToken._chr = startChr;
                    if (!input.empty)
                        input.popFront();
                    break loop;
            }
        }
        input.clearStash();
    }

    @property ref Range range()
    {
        return input.range;
    }
    
    @property void range(ref Range r)
    {
        input.range     = r;
        crtToken        = Token(TokenType.none);
        crtToken._chr = r.front;
    }

    // zinc spec version
    int ver = 3;

    // internals
private:
    
    @disable this();
    @disable this(this);

    bool isEmpty = false;

    // ctfe code gen for lexing a type
    static string lexInstruction(string tok, string next)
    {
        return "if(lex" ~ tok ~"())" ~
            "    break loop;" ~
            "else" ~
            "   tryToken = TokenType." ~ next ~ ";" ~
            "continue loop;";
    }

    bool lexId()
    {
        enum State {req, opt}
    loop:
        for (State crtState; !input.empty; input.popFront())
        {
            final switch (crtState)
            {
                case State.req: // required to start with lower case alpha
                    if (cur.isLower)
                    {
                        input.stash();
                        crtState++;
                        continue;
                    }
                    return false;

                case State.opt:
                    if (cur.isAlphaNum || cur == '_')
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
        // bad
        assertTokenEmpty("BAD%Id");
    }

    bool lexNull()
    {
        if (cur == 'N')
        {
            if (!input.empty) // probe if this has more
            {
                input.stash();
                input.popFront();
            }
            if (input.empty 
                || !(cur.isAlphaNum || cur == '_')) // test for next token
            {
                crtToken = Token(TokenType.null_, Tag());
                return true;
            }
            else
            {
                input.save(); // save look ahead
            }
        }
        return false;
    }
    unittest
    {
        // good
        assertTokenValue("N", Token(TokenType.null_));
        assertTokenValue("N ", Token(TokenType.null_));
        // bad
        assertTokenEmpty("X");
    }

    bool lexMarker()
    {
        if (cur == 'M')
        {
            input.stash();
            input.popFront();
            if (!input.empty && (cur.isAlphaNum || cur == '_'))
            {
                input.save;
                return false;
            }
            crtToken = Token(TokenType.marker, marker());
            return true;
        }
        return false;
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
        if (cur == 'R')
        {
            input.stash();
            input.popFront();
            if (!input.empty && (cur.isAlphaNum || cur == '_'))
            {
                input.save;
                return false;
            }
            crtToken = Token(TokenType.remove, Tag.init);
            return true;
        }
        return false;
    }
    unittest
    {
        // good
        assertTokenValue("R", Token(TokenType.remove));
        assertTokenValue("R ", Token(TokenType.remove));
        assertTokenValue("R|", Token(TokenType.remove));
        // bad
        assertTokenEmpty("K");
    }

    bool lexNa()
    {
        if (cur == 'N' && !input.empty)
        {
            input.stash();
            input.popFront();
            if (cur == 'A')
            {
                input.stash();
                if (!input.empty)
                    input.popFront();
                if (!input.empty && (cur.isAlphaNum || cur == '_')) // test for posible XStr
                {
                    input.stash();
                    input.save;
                    return false;
                }
                crtToken = Token(TokenType.na, Na().Tag);
                return true;
            }
            // more to lex
            input.stash();
            input.popFront();
            input.save();
        }
        return false;
    }
    unittest
    {   
        // good
        assertTokenValue("NA", Token(TokenType.na));
        assertTokenValue("NA,", Token(TokenType.na));
        // bad
        assertTokenEmpty("NAM,");
        assertTokenEmpty("XY");
    }

    bool lexBool()
    {
        if (cur == 'T' || cur == 'F')
        {
            dchar val = cur;
            input.stash();
            input.popFront();
            if (!input.empty && (cur.isAlphaNum || cur == '_')) // test for posible XStr
            {
                input.save;
                return false;
            }            
            crtToken = Token(TokenType.bool_, (val == 'T').tag);
            return true;
        }
        return false;
    }
    unittest
    {
        // good
        assertTokenValue("T", Token(TokenType.bool_, true.tag));
        assertTokenValue("T ", Token(TokenType.bool_, true.tag));
        assertTokenValue("F", Token(TokenType.bool_, false.tag));
        assertTokenValue("F,", Token(TokenType.bool_, false.tag));
        // bad
        assertTokenEmpty("K");
    }

    bool lexRef()
    {
        string val;
        string dis;
        if (cur == '@')
        {
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
                else if (lexWs && input.hasStash)
                {
                    input.popFront(); // skip ws
                    val = input.commitStash();
                    if (lexStr())
                    {
                        dis = crtToken.value!Str;
                        crtToken = Token.init;
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
                    return false;
            }
            if (val is null)
                val = input.commitStash();
            crtToken = Token(TokenType.ref_, Tag(Ref(val, dis)));
            return true;
        }
        return false;
    }
    unittest
    {
        // good
        assertTokenValue("@fooBar", Token(TokenType.ref_, Ref("fooBar").Tag));
        assertTokenValue(`@fooBar "a nice description"`, Token(TokenType.ref_, Ref("fooBar", "a nice description").Tag));
        assertTokenValue(`@fooBar ,`, Token(TokenType.ref_, Ref("fooBar").Tag));
        // bad
        assertTokenEmpty("&");
        assertTokenEmpty("@#");
    }

    string lexChars(immutable char[] esc, immutable char[] escVal, char quoteChar = '"')
    {
        import std.format   : formattedRead;
        import std.string   : indexOf;

        bool hasTerm = false;
        if (cur == quoteChar && !input.empty)
        {
            for (input.popFront(); !input.empty; input.popFront())
            {
            loop:
                if (cur == quoteChar) // found terminator
                {
                    hasTerm = true;
                    input.popFront();
                    break;
                }
                if (cur >= ' ')
                {
                    if (cur == '\\')
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
                            dchar uni; 
                            int count = input.formattedRead("%x", &uni);
                            if (count)
                            {
                                input.stash(uni);
                                // we consumed all u's chars, no need to popFront
                                goto loop;
                            }
                            else 
                                return null;
                        }
                        ptrdiff_t escPos = esc.indexOf(cur);
                        if (escPos != -1)
                            input.stash(escVal[escPos]);
                        else
                            return null;
                    }
                    else
                    {
                        input.stash();
                    }
                }
                else 
                    return null;
            }
            if (!hasTerm)
                return null;
            if (!input.hasStash)
                return "";
            return input.commitStash();
        }
        return null;
    }

    bool lexStr()
    {
        enum quoteChar = '"';
        static immutable strEsc = [ 'n', 'r', 't', '"', '\\', '$', 'b', 'f'];
        static immutable strEscVal = ['\n', '\r', '\t', '"', '\\', '$', '\b', '\f'];
        string chars = lexChars(strEsc, strEscVal, quoteChar);
        if (chars !is null)
        {
            crtToken = Token(TokenType.str, chars.tag);
            return true;
        }
        return false;
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
        assertTokenEmpty(`"fooo`);
        assertTokenEmpty(`"a bad \u"`);
    }

    bool lexUri()
    {
        enum quoteChar = '`';
        static immutable uriEsc = [':', '/', '?', '#', '[', ']', '@', '`', '\\', '&', '=', ';'];
        static immutable uriEscVal = [':', '/', '?', '#', '[', ']', '@', '`', '\\', '&', '=', ';'];
        string chars = lexChars(uriEsc, uriEscVal, quoteChar);
        if (chars !is null)
        {
            crtToken = Token(TokenType.uri, cast(Tag)Uri(chars));
            return true;
        }
        return false;
    }
    unittest
    {
        // good
        assertTokenValue("`/a/b/c`", Token(TokenType.uri, cast(Tag)Uri("/a/b/c")));
        // bad
        assertTokenEmpty("`");
    }

    bool lexNumber()
    {
        enum State {integral, fractional_digit, fractional, exp_sign, exp, unit}
        // test the optional sign
        if (cur == '-')
        {
            if (input.empty)
                return false;
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
            static double parseNum(const(char)[] chars, ref double val)
            {
                import std.format : formattedRead;
                string str = cast(string)chars;
                str.formattedRead("%g", &val);
                return val;
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
                            crtState = State.fractional_digit;
                        }
                        else if (cur.isAlpha || cur == '%' || cur == '_' || cur == '/' || cur == '$' || cur > 127)
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

                    case State.fractional_digit:
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
                            crtState = State.exp_sign;
                        }
                        else if (cur.isAlpha || cur == '%' || cur == '_' || cur == '/' || cur == '$' || cur > 127)
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

                    case State.exp_sign:
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
                        else if (cur.isAlpha || cur == '%' || cur == '_' || cur == '/' || cur == '$' || cur > 127)
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
                        if (cur.isAlpha || cur == '%' || cur == '_' || cur == '/' || cur == '$' || cur > 127)
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
            import std.math : isNaN;
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
            if (cur == 'N')
            {
                crtToken = Token(TokenType.number, tag(double.nan));
                input.popFront();
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
        assertTokenEmpty("_12");
    }

    bool lexDate()
    {
        import std.conv : to;
        enum State {year, month, day}
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
                        parts++;
                        if (parts > 4) // to many digits
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
                        parts++;
                    }
                    else if (parts != 6)
                    {
                        return false;
                    }
                    else if (cur == '-')
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
                    if (cur.isDigit)
                    {
                        input.stash();
                        parts++;
                    }
                    else
                        return false;
                    if (parts == 8)
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
        enum State {hours, minutes, sec, fraction}
        State crtState;
        int hours, minutes, sec, fraction;
        int parts = 0;
    loop:
        for (; !input.empty; input.popFront())
        {
            final switch (crtState)
            {
                case State.hours:
                    if (cur.isDigit) // check the 2nd digit of the hours number
                    {
                        input.stash();
                        parts++;
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
                        parts++;
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
                        if (parts == 6)
                        {
                            sec = to!int(input.crtStash());
                            input.clearStash();
                        }
                    }
                    else if (cur == '.' && parts == 6)
                    {
                        crtState++;
                    }
                    else
                    {
                        break loop; // seconds complete
                    }
                    break;

                case State.fraction:
                    if (cur.isDigit)
                    {
                        input.stash();
                        parts++;
                    }
                    else if (parts == 6)
                    {
                        return false;
                    }
                    else
                    {
                        break loop; // fraction complete 
                    }
                    break;
            }
        }
        if (parts >= 6) // sanity check for our time
        {
            if (parts > 6) // has fraction
            {
                fraction = to!int(input.crtStash());
                input.clearStash();
            }
            crtToken = Token(TokenType.date, Time(hours, minutes, sec, fraction).Tag);
            return true;
        }
        return false;
    }
    unittest
    {
        // good
        assertTokenValue("09:40:03", Token(TokenType.date, Time(09, 40, 03).Tag));
        assertTokenValue("23:59:59", Token(TokenType.date, Time(23, 59, 59).Tag));
        assertTokenValue("23:59:59.999", Token(TokenType.date, Time(23, 59, 59, 999).Tag));
        // bad
        assertTokenValue("8:00", Token(TokenType.number, 8.tag));
        assertTokenValue("05:12", Token(TokenType.number, 5.tag));
        assertTokenValue("23:", Token(TokenType.number, 23.tag));
    }
    // used for both Date and DateTime lexing
    bool lexDateTime()
    {
        Tag date;
        Tag time;
        if (lexDate() && !input.empty) // try the date part
        {
            if (cur == 'T') // check the time marker
            {
                date = crtToken.data;
                input.clearStash(); // clear the date stash
                input.popFront(); // move next
                crtToken = Token.init;
                if (input.empty) // it must have more
                    return false;
                if (lexTime()) // get the time part
                {
                    if (input.empty)
                        return false;
                }
                else
                {
                    return false;
                }
                time = crtToken.data;
                input.clearStash(); // clear the time stash
                crtToken = Token.init;
                enum State {utc, hours, minutes, tz}
                int count = 0;
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
                                crtState++;
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
                                count++;
                                continue;
                            }
                            else if (count < 2) // must be number
                            {
                                return false;
                            }
                            if (cur == ':' && count == 2) // got 2 numbers and a separator
                            {
                                input.stash();
                                count = 0;
                                crtState++;
                                continue;
                            }
                            // no separator found
                            if( count > 2)
                            {
                                return false;
                            }
                            break;

                        case State.minutes:
                            if (cur.isDigit) // minutes number
                            {
                                input.stash();
                                count++;
                                if (count == 2) // found the minutes number
                                {
                                    offset = input.commitStash();
                                    count = 0;
                                    crtState++;
                                }
                                continue;
                            }
                            else if (count < 2) // must be number
                            {
                                return false;
                            }
                            break;

                        case State.tz:
                            if (count == 0)
                            {
                                if (cur == ' ')
                                {
                                    count++;
                                    continue;
                                }
                                else
                                {
                                    break loop;
                                }
                            }
                            
                            if (count == 1) // ensure tz starts with an alpha
                            {
                                if (cur.isAlpha)
                                {
                                    input.stash();
                                    count++;
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
                import core.time : msecs;
                import std.datetime : UTC;
                DateTime dt = DateTime(date.get!Date, time.get!Time);
                if (tzName.empty || tzName == "UTC")
                {
                    crtToken = Token(TokenType.dateTime, SysTime(dt, msecs((time.get!Time).millis), UTC()).Tag);
                }
                else
                {
                    import haystack.zinc.tzdata;
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
            // got a date part
            return true;
        }
        return false;
    }
    unittest
    {
        import core.time : msecs;
        import std.datetime : TimeZone, UTC;

        // good
        assertTokenValue("2017-01-17T13:51:20Z", Token(TokenType.dateTime, SysTime(DateTime(2017, 01, 17, 13, 51, 20), UTC()).Tag));
        assertTokenValue("2009-11-09T15:39:00Z", Token(TokenType.dateTime, SysTime(DateTime(2009, 11, 09, 15, 39, 00), UTC()).Tag));
        assertTokenValue("1989-12-21T15:39:00Z UTC", Token(TokenType.dateTime, SysTime(DateTime(1989, 12, 21, 15, 39, 00), UTC()).Tag));
        assertTokenValue("2015-03-31T18:06:41.956Z", Token(TokenType.dateTime, SysTime(DateTime(2015, 03, 31, 18, 06, 41), msecs(956), UTC()).Tag));
        
        import haystack.zinc.tzdata;
        assertTokenValue("2010-08-31T08:45:00+02:00 Europe/Athens", Token(TokenType.dateTime, SysTime(DateTime(2010, 08, 31, 08, 45, 00), timeZone("Europe/Athens")).Tag));
        assertTokenValue("2010-08-31T08:45:00-05:00 New_York", Token(TokenType.dateTime, SysTime(DateTime(2010, 08, 31, 08, 45, 00), timeZone("New_York")).Tag));
        assertTokenValue("2010-08-31T08:45:00+02:00 Nicosia", Token(TokenType.dateTime, SysTime(DateTime(2010, 08, 31, 08, 45, 00), timeZone("Asia/Nicosia")).Tag));
        // bad
        assertTokenEmpty("2009-11-09T");
        assertTokenEmpty("2009-11-09T4");
    }

    bool lexCoord()
    {
        double lat, lng;
        enum State { c, p, lat, lng, done }
        State state;
        for(; !input.empty && state != State.done; input.popFront())
        {
            final switch (state)
            {
                case State.c:
                    if (cur == 'C')
                    {
                        input.stash();
                        state++;
                        continue;
                    }
                    return false;
                
                case State.p:
                    if (cur == '(')
                    {
                        input.stash();
                        state++;
                        continue;
                    }
                    return false;

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
                    state++;
                    continue;

                case State.lng:
                    if (!lexNumber())
                        return false;
                    if (cur != ')')
                        return false;
                    lng = crtToken.data.val!Num;
                    state++;
                    break;

                case State.done:
                    assert(false, "Invalid state");
            }
        }
        crtToken = Token(TokenType.coord, Coord(lat, lng).Tag);
        return true;
    }
    unittest
    {
        // good
        assertTokenValue("C(37.545826,-77.449188)", Token(TokenType.coord, Coord(37.545826,-77.449188).Tag));
        //assertTokenValue(`Massive("\n")`, Token(TokenType.xstr, XStr("Massive", "\n").Tag));
        // bad
        //assertTokenEmpty(`Xx(")`);
        //assertTokenEmpty(`Yx(""`);
    }

    bool lexXStr()
    {
        enum State { firstChar, opt, enc, done }
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
                    crtState    = State.opt;
                    break;

                case State.opt:
                    if (cur.isAlphaNum || cur == '_')
                        input.stash();
                    else if (cur == '(')
                    {
                        type        = input.commitStash();
                        crtState    = State.enc;
                    }
                    else
                        return false;
                    break;

                case State.enc:
                    if (!lexStr()) // consumes the string
                        return false;
                    data = crtToken.data.get!Str;
                    crtToken = Token.init;
                    // check next char
                    if (!input.empty && cur == ')')
                        crtState    = State.done;
                    else
                        return false;
                    break;
                    
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
        enum State { bin, mime, end }
        State crtState;
        for(; !input.empty; input.popFront())
        {
            final switch (crtState)
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
                    crtState    = State.mime;
                    break;

                case State.mime:
                    if (cur != ')')
                        input.stash();
                    else
                        crtState = State.end;
                    break;

                case State.end:
                    string data = input.commitStash();
                    crtToken = Token(TokenType.xstr, XStr("Bin", data).Tag);
                    return true;
            }
        }
        return false;
    }
    unittest
    {
        assertTokenValue(`Bin(text/plain),`, Token(TokenType.xstr, XStr("Bin", "text/plain").Tag), 2);
        assertTokenEmpty(`Bad(text/plain),`, 2);
    }

    bool lexWs()
    {
        return cur == ' ' || cur == '\t';
    }

    bool lexSep()
    {
        return lexWs || cur == ','
            || cur == '\n';
    }

private:
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
    assert(lex.front() == Token.init);
}

package void dumpLexer(Lexer)(auto ref Lexer lex)
{
    import std.algorithm : move;
    import std.stdio : writeln;
    import std.conv : to;
    foreach (ref tk; move(lex))
    {
        writeln("Token type: ", tk.type, " value: '", tk.type != Lexer.TokenType.none ? tk.tag.toStr() : to!string(tk.chr), "'");
    }
}