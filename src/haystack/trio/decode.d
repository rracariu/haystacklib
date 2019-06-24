// Written in the D programming language.
/**
Haystack trio decode.

Copyright: Copyright (c) 2019, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.trio.decode;

import std.traits : isSomeChar;
import std.range.primitives : empty, isInputRange, ElementEncodingType;

import haystack.tag;
import haystack.zinc.lexer;
import haystack.zinc.decode;

/*
Parses a Trio encoded `InputRange`
*/
struct TrioParser(Range)
if (isInputRange!Range && isSomeChar!(ElementEncodingType!Range))
{
    alias Lexer     = ZincLexer!Range;
    alias Parser    = ZincParser!Range;

    this(Range r)
    {
        this.parser = Parser(r);
        if (!r.empty)
            popFront();
        else
            state = State.fault;
    }
    @disable this();
    @disable this(this);

    /// True until parsing error or parsing complete
    @property bool empty()
    {
        return (state == State.done || state == State.fault);
    }

    /// The last parsed `Dict`
    @property Dict front()
    {
        assert(!empty, "Attempting to access front of an empty Trio.");
        return dict;
    }

    /// Parse next `Dict`
    void popFront()
    {
        if (lexer.empty)
        {
            state = State.done;
            return;
        }

        dict = Dict.init;
        string key;

        // trio parsing state machine
        loop:
        for (; !empty; lexer.popFront())
        {
            start:
            switch (state)
            {
                case State.key:
                    // must start with valid key
                    if (lexer.empty || !lexer.front.isId)
                    {
                        if (isCommentChar)
                        {
                            state = State.comment;
                            goto start;
                        }
                        state = State.fault;
                        break loop;
                    }
                    key     = lexer.front.value!Str;
                    state   = State.valueSep;
                    break;

                case State.valueSep:
                    if (lexer.front.isSpace)
                        continue;
                    // marker symbol
                    if (lexer.empty || lexer.front.isNewLine)
                    {
                        dict[key]   = marker;
                        state       = State.nextLine;
                        goto start;
                    }
                    else if (isValueSeparatorChar)
                    {
                        state = State.value;
                        continue;
                    }
                    break;
 
                case State.value:
                    if (lexer.front.isSpace)
                        continue;

                    if (lexer.empty)
                    {
                        state = State.fault;
                        break loop;
                    }

                    // Special casing for str and xstr
                    if ((!lexer.front.isValid && !isComplexType) 
                        || lexer.front.isId)
                    {
                        // multiline string
                        if (lexer.front.isNewLine)
                        {
                            auto val    = lexXStr();
                            dict[key]   = Str(val);
                        }
                        else
                        {
                            // unquoted string start
                            // could match and id
                            if (lexer.front.isId)
                            {
                                foreach (c; lexer.front.value!Str)
                                    lexer.buffer.stash(c);
                            }
                            auto type   = lexStr();
                            // get the separator char
                            lexer.popFront();
                            // XStr encoding
                            if (isValueSeparatorChar)
                            {
                                lexer.popFront();
                                // expect newline
                                if (lexer.empty || !lexer.front.isNewLine)
                                {
                                    state = State.fault;
                                    break loop;
                                }
                                lexer.popFront();
                                if (lexer.empty)
                                {
                                    state = State.fault;
                                    break loop;
                                }
                                auto val    = lexXStr();
                                dict[key]   = XStr(type, val);
                                state = State.nextLine;
                                goto start;
                            }
                            else // simple unquoted string
                            {
                                dict[key]   = Str(type);
                            }
                        }
                    }
                    else // scalar, list, dict 
                    {
                        auto el     = Parser.AnyTag(parser);
                        dict[key]   = cast() el.asTag;
                    }

                    state = State.nextLine;
                    break;

                case State.nextLine:
                    if (lexer.empty)
                        break loop;

                    if (lexer.front.isSpace)
                        continue;                    
                    
                    if (lexer.front.isValid)
                    {
                        state = State.key;
                        goto start;
                    }
                    else if (isNextDictChar)
                    {
                        state = State.nextDict;
                        continue;
                    }
                    else if (isCommentChar)
                    {
                        lexer.popFront();
                        if (lexer.empty || !isCommentChar)
                        {
                            state = State.fault;
                            break loop;
                        }
                        state = State.comment;
                        continue;
                    }
                    else if (!lexer.front.isNewLine)
                    {
                        state = State.fault;
                        break loop;
                    }
                    break;

                case State.nextDict:
                    if (lexer.empty)
                        break loop;

                    if (isNextDictChar)
                        continue;

                    if (lexer.front.isNewLine)
                    {
                        state = State.key;
                        lexer.popFront();
                        break loop;
                    }
                    else
                    {
                        state = State.fault;
                        break loop;
                    }

                case State.comment:
                    if (lexer.empty)
                        break loop;

                    if (!lexer.front.isNewLine)
                        continue;

                    state = State.nextLine;
                    goto start;

                default:
                    assert(false, "Invalid parser state.");
            }
        }
    }

    /// Definitions of parser states
    enum State { key, valueSep, value, nextLine, nextDict, comment, fault, done };
    /// Current parser state
    State state;

private:
    
    @property scope Lexer* lexer() return
    {
       return &this.parser.lexer;
    }

    // Read a single line of unquoted text
    string lexStr()
    {
        import std.uni : isAlpha, isSpace;
        
        scope range = &lexer.buffer();
        range.save();

        for (; !range.empty; range.popFront())
        {
            if (range.front.isAlpha 
                || range.front == '_'
                || range.front == '#'
                || range.front.isSpace)
                range.stash();
            else
                break;
        }
        return range.commitStash();
    }

    // Read multiline string
    string lexXStr()
    {
        import std.uni : isControl, isSpace, isWhite;

        enum XStrState { line, nextLine}
        XStrState thisState;

        scope range = &lexer.buffer();
        range.save();

        loop:
        for (; !range.empty; range.popFront())
        {
            final switch (thisState)
            {
                case XStrState.line:
                    if (range.front.isSpace)
                        continue;  
                    if (range.front.isWhite && range.front.isControl)
                    {
                        thisState = XStrState.nextLine;
                        continue;
                    }
                    range.stash();
                    break;
                 
                case XStrState.nextLine:
                    if (range.front.isSpace)
                    {
                        thisState = XStrState.line;
                        continue;
                    }
                    break loop;
            }
        }
        return range.commitStash();
    }

    @property bool isCommentChar() pure
    {
        return lexer.front.hasChr('/');
    }

    @property bool isNextDictChar() pure
    {
        return lexer.front.hasChr('-');
    }

    @property bool isValueSeparatorChar() pure
    {
        return lexer.front.hasChr(':');
    }

    @property bool isComplexType() pure
    {
        return lexer.front.hasChr('[') || lexer.front.hasChr('{');
    }

    Dict dict;
    Parser parser = void;
}

alias TrioStringDecoder = TrioParser!string;

unittest
{
    auto scalars = q"{marker
na: NA
bool: T
number: 1234.5$
str: "ana are mere si pere"
strSimple:a simple string
xstr:Foo:
    blah
coord: C(37.545826,-77.449188)
uri: `/a/b/c`
ref:@someId
date:2019-06-06
time: 15:23:03
dateTime:2019-04-09T15:24:00+02:00 Europe/Athens
}";

    auto decoder = TrioStringDecoder(scalars);
    auto dict    = decoder.front();

    assert(dict.has!Marker("marker"));
    assert(dict.has!Na("na"));
    assert(dict.get!Bool("bool") == true);
    assert(dict.get!Num("number") == Num(1234.5, "$"));
    assert(dict.get!Str("str") == "ana are mere si pere");
    assert(dict.get!Str("strSimple") == "a simple string");
    assert(dict.get!XStr("xstr") == XStr("Foo", "blah"));
    assert(dict.get!Coord("coord") == Coord(37.545826,-77.449188));
    assert(dict.get!Uri("uri") == Uri(`/a/b/c`));
    assert(dict.get!Ref("ref") == Ref("someId"));
    assert(dict.get!Date("date") == Date(2019, 6, 6));
    assert(dict.get!Time("time") == Time(15, 23, 3));
}


unittest
{
    import std.algorithm: move;
    auto scalars = 
q"{foo
bar
---
n:3}";

   auto decoder = TrioStringDecoder(scalars);
   Dict[] dicts;

   foreach (d; decoder.move)
       dicts ~= d;

   assert(dicts.length == 2);
   assert(dicts[0].has!Marker("foo"));
   assert(dicts[1].get!Num("n").to!int == 3);
}

unittest
{
    auto complex = q"{list:[1,"str",T]
dict: {ana:"are" mere}
// some comment
grid:Zinc:
    ver:"3.0"
    empty
}";

    auto decoder = TrioStringDecoder(complex);
    auto dict    = decoder.front();
    assert(dict.has!TagList("list"));
    assert(dict.has!Dict("dict"));
    assert(dict.has!XStr("grid"));
}
unittest
{
    import std.algorithm: move;
    auto comment = 
        q"{// A comment
        value:1}";

    auto decoder = TrioStringDecoder(comment);

    assert(decoder.front.length == 1);
    assert(decoder.front.get!Num("value").to!int == 1);
}