// Written in the D programming language.
/**
Haystack zinc decode.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.decode;

import std.algorithm : move;
import std.traits : isSomeChar;
import std.range.primitives : empty, isInputRange, ElementEncodingType;

import haystack.tag;
import haystack.zinc.lexer;
import haystack.zinc.util : Own, LookAhead;

///////////////////////////////////////////////////////////////////
//
// Tag Decoding from Zinc
//
///////////////////////////////////////////////////////////////////

/*
Parses a Zinc encoded $(Input Range)
*/
struct ZincParser(Range)
if (isInputRange!Range && isSomeChar!(ElementEncodingType!Range))
{
    alias Parser    = ZincParser!Range;
    alias Lexer     = ZincLexer!Range;

    this(Range r)
    {
        this.lexer = Lexer(r);
        if (!r.empty)
            popFront();
        else
            state = ParserState.fault;
    }
    @disable this();
    @disable this(this);

    /// True until parsing error or parsing complete
    @property bool empty()
    {
        return (state == ParserState.ok || state == ParserState.fault);
    }

    /// The last parsed $(D Element)
    @property ref Element front()
    {
        assert(!empty, "Attempting to access front of an empty Grid.");
        return element;
    }

    /// Parse next $(D Element)
    void popFront()
    {
        assert(!empty, "Attempting to pop from an empty Grid.");
        // grid parsing state machine
    loop:
        for(; !empty; lexer.popFront())
        {
            final switch (state)
            {
                case ParserState.header:
                    if (element.type == Element.Type.header)
                    {
                        if (element.header.consume() && isNl)
                        {
                            lexer.popFront();
                            state++;
                        }
                        else
                            state = ParserState.fault;
                    }
                    else
                    {
                        element.header = Header(this);
                    }
                    return;

                case ParserState.colums:
                    if (element.type == Element.Type.columns)
                    {
                        if (element.columns.consume() && isNl)
                        {
                            lexer.popFront();
                            state++;
                        }
                        else
                            state = ParserState.fault;
                    }
                    else
                    {
                        element.columns = Columns(this);
                    }
                    return;

                case ParserState.rows:
                    if (element.type == Element.Type.rows)
                    {
                        if (element.rows.consume())
                        {
                            if (isNl)
                            {
                                lexer.popFront();
                                if (isNl || lexer.empty)
                                    state = ParserState.ok;
                                else
                                    element.rows = Rows(this);
                            }
                            else if (lexer.empty || hasChr('>'))
                            {
                                state = ParserState.ok;
                            }
                            else
                            {
                                state = ParserState.fault;
                            }
                        }
                        else
                            state = ParserState.fault;
                    }
                    else
                    {
                        if (isWs)
                            continue;
                        if (isNl)
                            state = ParserState.ok;
                        else
                            element.rows = Rows(this);
                    }
                    return;

                case ParserState.ok:
                case ParserState.fault:
                    assert(false, "Invalid parser state.");
            }
        }
    }

    /*
    The atomic parts of a Grid.
    It holds type and value information about header, columns, rows 
    */
    static struct Element
    {
        /// Each Element type
        enum Type { header, columns, rows, none = uint.max }
        Type type = Type.none;

        @property void header(Header header)
        {
            type = Type.header;
            move(header, _value.header);
        }

        @property ref Header header()
        {
            assert(type == Type.header);
            return _value.header;
        }

        @property void columns(Columns columns)
        {
            type = Type.columns;
            move(columns, _value.columns);
        }

        @property ref Columns columns()
        {
            assert(type == Type.columns);
            return _value.columns;
        }

        @property void rows(Rows rows)
        {
            type = Type.rows;
            move(rows, _value.rows);
        }

        @property ref Rows rows()
        {
            assert(type == Type.rows);
            return _value.rows;
        }

        string toString()
        {
            import std.format : format;
            return format("%s", type);
        }

    private:
        union Value
        {
            Header header = void;
            Columns columns = void;
            Rows rows = void;
        }
        Value _value;
        @disable this(this);
    }
    
    /**
    Parses the $(D InputRange) and constructs an in-memory $(D Grid)
    */
    immutable(Grid) asGrid()
    {
        string ver;
        Dict gridMeta;
        import std.array : appender;
        auto colList = appender!(Grid.Col[])();
        auto rowsList = appender!(Dict[])();
        for(; !empty; popFront)
        {
            auto el = &front();
            if (el.type == Parser.Element.Type.header)
            {
                for (; !el.header.empty; el.header.popFront)
                {
                    auto h = &el.header.front();
                    if (h.type == Parser.Header.Type.ver)
                        ver = h.ver;
                    else if (h.type == Parser.Header.Type.tags)
                    {
                        for (; !h.tags.empty; h.tags.popFront)
                        {
                            h.tags.front.asDict(gridMeta);
                        }
                    }
                }
            }
            if (el.type == Parser.Element.Type.columns)
            {
                for (; !el.columns.empty; el.columns.popFront)
                {
                    auto col = &el.columns.front();
                    if (col.type == Parser.Columns.Type.name)
                    {
                        colList.put(Grid.Col(col.name));
                    }
                    else if (col.type == Parser.Columns.Type.tags)
                    {
                        scope column = &colList.data[$ - 1];
                        for (; !col.tags.empty; col.tags.popFront)
                        {
                            col.tags.front.asDict(column.meta);
                        }
                    }
                }
            }
            if (el.type == Parser.Element.Type.rows)
            {
                Dict row;
                for (size_t i = 0; !el.rows.empty; el.rows.popFront(), i++)
                {
                    row[colList.data[i].dis] =  el.rows.front.asTag;
                }
                if (row !is null)
                    rowsList.put(row);
            }
        }
        return cast(immutable) Grid(rowsList.data, colList.data, gridMeta, ver);
    }

    Tag asTag()
    {
        return Tag(cast(Grid) asGrid);
    }

    /// Definitions of parser states
    enum ParserState { header, colums, rows, ok, fault };
    /// Current parser state
    ParserState state;

    /// The $(D InputRange) the parser uses
    @property ref Range range()
    {
        return lexer.range;
    }
    @property void range(ref Range range)
    {
        lexer.range = range;
    }

    ///////////////////////////////////////////////////////////////////////
    //
    // Header parsing
    //
    ///////////////////////////////////////////////////////////////////////

    /// Parser the header portion of a $(D Grid)
    struct Header
    {
        enum Type { ver, tags }

        struct Value
        {
            Type type;
            union 
            {
                string ver;
                NameValueList tags;
            }
        }

        @property bool empty()
        {
            return state == HeaderState.ok
                || state == HeaderState.fault;
        }

        @property ref Value front()
        {
            return value;
        }

        void popFront()
        {
            for(; !empty; parser.lexer.popFront())
            {
                switch (state)
                {
                    case HeaderState.ver:
                        if (parser.isWs() && !parser.lexer.empty)
                            continue;
                        if (!parseVer())
                            state = HeaderState.fault;
                        else 
                        {
                            value.type = Type.ver;
                            state++;
                        }
                        return; // stop if ver found

                    case HeaderState.tags:
                        if (parser.isNl)
                        {
                            state = HeaderState.ok;
                        }
                        else if (value.type == Type.tags)
                        {
                            if (!value.tags.consume)
                                state = HeaderState.fault;
                            else
                                state = HeaderState.ok;
                            return;
                        }
                        else
                        {
                            value.type = Type.tags;
                            auto tp = NameValueList(*parser); 
                            move(tp, value.tags);
                        }
                        return;

                    default:
                        break;
                }
            }
        }

        bool consume()
        {
            for (; !empty(); popFront()) {}
            return state == HeaderState.ok;
        }

        // implementation
    private:
        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!parser.lexer.empty)
                popFront();
            else
                state = HeaderState.fault;
        }
        @disable this();
        @disable this(this);

        Parser* parser = void;
        Value value = void;
        enum HeaderState { ver, tags, ok, fault }
        HeaderState state;

        // parse a grid version
        bool parseVer()
        {
            enum VerState { ver, sep, str, done}
            VerState state;
        loop:
            for (; !parser.lexer.empty(); parser.lexer.popFront())
            {
                if (parser.isWs())
                    continue;
                final switch (state)
                {
                    case VerState.ver:
                        if (!parser.expectToken(TokenType.id, "ver".tag))
                            return false;
                        state++;
                        break;

                    case VerState.sep:
                        if (!parser.hasChr(':'))
                            return false;
                        state++;
                        break;

                    case VerState.str:
                        if (!parser.expectToken(TokenType.str))
                            return false;
                        value.ver = parser.token.value!Str;
                        if (parser.lexer.empty)
                            return true;
                        state++;
                        break;

                    case VerState.done:
                        break loop;
                }
            }
            return state == VerState.done;
        }
    } ///
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser(`ver:"3.0"`);
            auto header = &parser.front.header();
            assert(header.front.type == Parser.Header.Type.ver);
            assert(header.front.ver == "3.0");
        }
    }

    ///////////////////////////////////////////////////////////////////////
    //
    // Column parsing
    //
    ///////////////////////////////////////////////////////////////////////

    /// Parser the column portion of a $(D Grid)
    struct Columns
    {
        enum Type { name, tags }

        struct Value
        {
            Type type;
            union 
            {
                string name;
                NameValueList tags;
            }
        }

        @property bool empty()
        {
            return state == ColumnsState.ok
                || state == ColumnsState.fault;
        }

        @property ref Value front()
        {
            return value;
        }

        void popFront()
        {
            for(; !empty; parser.lexer.popFront())
            {
            eval:
                switch (state)
                {
                    case ColumnsState.name:
                        if (parser.isWs() && !parser.lexer.empty)
                            continue;
                        if (!parser.expectToken(TokenType.id))
                            state = ColumnsState.fault;
                        else 
                        {
                            value.type = Type.name;
                            value.name = parser.token.value!Str;
                            parser.lexer.popFront();
                            state++;
                        }
                        return; // stop if ver found

                    case ColumnsState.sep:
                        if (parser.hasChr(','))
                            state = ColumnsState.name;
                        else if (parser.hasChr(' '))
                            state++;
                        else if (parser.isNl || parser.lexer.empty)
                        {
                            state = ColumnsState.ok;
                            return;
                        }
                        continue;

                    case ColumnsState.tags:
                        if (parser.isNl)
                        {
                            state = ColumnsState.ok;
                        }
                        else if (value.type == Type.tags)
                        {
                            if (!value.tags.consume)
                                state = ColumnsState.fault;
                            else
                            {
                                state = ColumnsState.sep;
                                goto eval;
                            }
                            return;
                        }
                        else
                        {
                            value.type = Type.tags;
                            auto nv = NameValueList(*parser); 
                            move(nv, value.tags);
                        }
                        return;

                    default:
                        break;
                }
            }
        }

        bool consume()
        {
            for (; !empty(); popFront()) {}
            return state == ColumnsState.ok;
        }

        // implementation
    private:
        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!parser.lexer.empty)
                popFront();
            else
                state = ColumnsState.fault;
        }
        @disable this();
        @disable this(this);

        Parser* parser = void;
        Value value = void;
        enum ColumnsState { name, sep, tags, ok, fault }
        ColumnsState state;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser("col1, col2");
            auto cols = Parser.Columns(parser);
            assert(cols.front.name == "col1");
            cols.popFront;
            assert(cols.front.name == "col2");
        }
        {
            auto parser = Parser("col1 test,col2 bar:F");
            auto cols = Parser.Columns(parser); // pop col name
            assert(cols.front.name == "col1"); 
            cols.popFront; // pop col tags
            assert(cols.front.tags.asDict == ["test": marker]);
            cols.popFront; // pop col name
            assert(cols.front.name == "col2");
            cols.popFront; // po col tags
            assert(cols.front.tags.asDict == ["bar": false.tag]);
        }

    }

    ///////////////////////////////////////////////////////////////////////
    //
    // Row parsing
    //
    ///////////////////////////////////////////////////////////////////////

    /// Parser the rows portion of a $(D Grid)
    struct Rows
    {
        @property bool empty()
        {
            return state == RowsState.ok
                || state == RowsState.fault;
        }

        @property ref AnyTag front()
        {
            return value;
        }

        void popFront()
        {
            for(; !empty; parser.lexer.popFront())
            {
                if (parser.isWs)
                {
                    if (!parser.lexer.empty)
                        continue;
                    else
                        state = RowsState.ok;
                }
                switch (state)
                {
                    case RowsState.tag:
                        if (parser.hasChr(','))
                        {
                            value = AnyTag(Tag.init);
                            if(parser.lexer.empty)
                                state =  RowsState.sep;
                            else
                                parser.lexer.popFront();
                        }
                        else if (parser.isNl)
                        {
                            value = AnyTag(Tag.init);
                            state++;
                        }
                        else
                        {
                            if (parser.hasChr('>'))
                            {
                                state = RowsState.ok;
                            }
                            else
                            {
                                value = AnyTag(*parser);
                                state = RowsState.sep;
                            }
                        }
                        return;

                    case RowsState.sep:
                        if (parser.lexer.empty)
                            state = RowsState.ok;
                        else if (parser.hasChr(','))
                        {
                            state = RowsState.tag;
                            if(parser.lexer.empty)
                                state =  RowsState.ok;
                            else
                                continue;
                        }
                        else if (parser.isNl)
                        {
                            state = RowsState.ok;
                        }
                        else if (value.consume)
                            state = RowsState.ok;
                        else
                            state = RowsState.fault;
                        return;

                    default:
                        break;
                }
            }
        }

        bool consume()
        {
            for (; !empty(); popFront()) {}
            return state == RowsState.ok;
        }

        // implementation
    private:
        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!parser.lexer.empty)
                popFront();
            else
                state = RowsState.fault;
        }
        @disable this();
        @disable this(this);

        Parser* parser = void;
        AnyTag value = void;
        enum RowsState { tag, sep, ok, fault }
        RowsState state;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser("100,T, , `/a/b/c`, @ref");
            auto rows = Parser.Rows(parser);
            assert(rows.front.asTag == 100.tag);
            rows.popFront;
            assert(rows.front.asTag == true.tag);
            rows.popFront;
            assert(rows.front.asTag == Tag.init);
            rows.popFront;
            assert(rows.front.asTag == Uri(`/a/b/c`));
            rows.popFront;
            assert(rows.front.asTag == Ref("ref"));
        }
    }

    //////////////////////////////////////////
    /// Components
    //////////////////////////////////////////

    /// Decode a list of pair of tags 
    struct NameValueList
    {
        NameValue value = void;

        @property bool empty()
        {
            return state == TagPairListState.ok
                || state == TagPairListState.fault;
        }

        @property ref NameValue front()
        {
            return value;
        }

        void popFront()
        {
            for(; !empty;)
            {
                final switch (state)
                {
                    case TagPairListState.tag:
                        value = NameValue(*parser);
                        state = TagPairListState.consume;
                        return;

                    case TagPairListState.consume:
                        if (!value.consume())
                        {
                            state = TagPairListState.fault;
                            return;
                        }
                        if (parser.hasChr(sep))
                        {
                            state = TagPairListState.tag;
                            parser.lexer.popFront();
                            continue;
                        }
                        else
                            state = TagPairListState.ok;
                        return;

                    case TagPairListState.ok:
                    case TagPairListState.fault:
                        assert(false, "Invalid state.");
                }
            }
        }

        bool consume()
        {
            for(; !empty; popFront()) {}
            return state == TagPairListState.ok;
        }

        void asDict(ref Dict dict)
        {
            for(; !empty; popFront()) 
            {
                foreach (ref kv; front.asDict.byKeyValue)
                    dict[kv.key] = kv.value;
            }
        }

        Dict asDict()
        {
            Dict dict;
            for(; !empty; popFront()) 
            {
                foreach (ref kv; front.asDict.byKeyValue)
                    dict[kv.key] = kv.value;
            }
            return dict;
        }

        Tag asTag()
        {
            return Tag(asDict());
        }

        this(ref Parser parser, char sep = ' ')
        {
            this.parser = &parser;
            this.sep = sep;
            if (!parser.lexer.empty)
                popFront();
            else
                state = TagPairListState.ok;
        }

    private:
        enum TagPairListState { tag, consume, ok, fault }
        TagPairListState state;

        @disable this();
        @disable this(this);
        char sep = void;
        Parser* parser = void;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser("foo bar");
            auto list = Parser.NameValueList(parser);
            assert(list.front.front.name == "foo");
            list.popFront();
            assert(list.front.front.name == "bar");
        }
        {
            auto parser = Parser("bool:T num:22");
            auto list = Parser.NameValueList(parser);
            assert(list.front.front.name == "bool");
            list.front.consume();
            assert(list.front.front.value.asTag == true.tag);
            list.popFront();
            assert(list.front.front.name == "num");
            list.front.consume();
            assert(list.front.front.value.asTag == 22.tag);
        }
        {
            auto parser = Parser(`str:"text" ref:@ref`);
            auto list = Parser.NameValueList(parser);
            assert(list.front.asDict == ["str": "text".tag]);
        }
        {
            auto parser = Parser(`test zum:1% zam`);
            auto list = Parser.NameValueList(parser);
            assert(list.asDict == ["test":marker, "zum": 1.tag("%"), "zam": marker]);
        }

    }

    //////////////////////////////////////////
    /// Decode a pair of tags 
    //////////////////////////////////////////
    struct NameValue
    {

        enum Type { marker, nameValue }
        Type type;

        struct Pair
        {
            string name;
            AnyTag value;
        }

        @property bool empty()
        {
            return state == NameValueState.ok
                || state == NameValueState.fault;
        }

        @property ref Pair front()
        {
            return pair;
        }

        void popFront()
        {
            for(; !empty; parser.lexer.popFront())
            {
                final switch (state)
                {
                    case NameValueState.name:
                        if (parser.isWs)
                            continue;
                        if (!parser.expectToken(TokenType.id))
                        {
                            state = NameValueState.fault;
                        }
                        else
                        {
                            pair.name = parser.token.value!Str;
                            parser.lexer.popFront();
                            state++;
                        }
                        return;

                    case NameValueState.sep:
                        if (parser.hasChr(':'))
                        {
                            state++;
                            continue;
                        }
                        else
                        {
                            type = Type.marker;
                            pair.value = AnyTag(marker);
                            state = NameValueState.ok;
                        }
                        return;

                    case NameValueState.value:
                        if (parser.isWs)
                            continue;
                        type = Type.nameValue;
                        pair.value = AnyTag(*parser);
                        state = NameValueState.consume;
                        return;

                    case NameValueState.consume:
                        if (!pair.value.consume())
                            state = NameValueState.fault;
                        else
                            state = NameValueState.ok;
                        return;

                    case NameValueState.ok:
                    case NameValueState.fault:
                        assert(false, "Invalid tag pair state.");
                }
            }
        }

        bool consume()
        {
            for(; !empty; popFront()) {}
            return state == NameValueState.ok;
        }

        void asDict(ref Dict d)
        {
            if (consume)
                d[pair.name] = pair.value.asTag;
        }

        Dict asDict()
        {
            if (consume)
                return [pair.name: pair.value.asTag];
            return Dict.init;
        }

    private:
        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!empty)
                popFront();
            else
                state = NameValueState.fault;
        }
        @disable this();
        @disable this(this);

        Parser* parser = void;
        Pair pair;
        enum NameValueState { name, sep, value, consume, ok, fault }
        NameValueState state;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser("foo");
            auto pair   = Parser.NameValue(parser);
            assert(pair.front.name == "foo");
            pair.popFront();
            assert(pair.front.value.asTag == marker);
        }
        {
            auto parser = Parser("test:F");
            auto pair = Parser.NameValue(parser);
            assert(pair.front.name == "test");
            pair.popFront();
            assert(pair.front.value.asTag == false.tag);
        }
        {
            auto parser = Parser("bar:M");
            auto pair = Parser.NameValue(parser);
            assert(pair.front.name == "bar");
            pair.popFront();
            assert(pair.front.value.asTag == marker);
        }
    }


    //////////////////////////////////////////
    /// Tag parsing components
    //////////////////////////////////////////

    /// Parsing for any type of $(D Tag)s
    struct AnyTag
    {
        @property bool empty()
        {
            return state == AnyTagState.ok
                || state == AnyTagState.fault;
        }
        /// Type of tag values
        union Val
        {
            Tag scalar      = void;
            TagList list    = void;
            TagDict dict    = void;
            TagGrid grid    = void;
        }

        @property ref Val front()
        {
            return val;
        }

        void popFront()
        {
            if (state == AnyTagState.scalar)
            {
                if (!parser.isScalar)
                {
                    state++;
                }
                else
                {
                    val.scalar = cast(Tag) parser.token.tag;
                    parser.lexer.popFront();
                    type = Type.scalar;
                    state = AnyTagState.ok;
                   return;
                }
            }

            if (state == AnyTagState.list)
            {
                if (!parser.hasChr('['))
                {
                    state++;
                }
                else
                {
                    val.list = TagList(*parser);
                    type = Type.list;
                    state = AnyTagState.ok;
                    return;
                }
            }

            if (state == AnyTagState.dict)
            {
                if (!parser.hasChr('{'))
                {
                    state++;
                }
                else
                {
                    val.dict = TagDict(*parser);
                    type = Type.dict;
                    state = AnyTagState.ok;
                    return;
                }
            }

            if (state == AnyTagState.grid)
            {
                if (!parser.hasChr('<'))
                {
                    state++;
                }
                else
                {
                    val.grid = TagGrid(*parser);
                    type = Type.grid;
                    state = !val.grid.empty ? AnyTagState.ok : AnyTagState.fault;
                    return;
                }
            }
           assert(false, "Invalid state.");
        }

        bool consume()
        {
            for(; !empty; popFront()) {}
            return state == AnyTagState.ok;
        }

        /// Parse a tag.
        Tag asTag()
        {
            assert(state == AnyTagState.ok);
            if (type == Type.scalar)
            {
                consume();
                return val.scalar;
            }
            else if (type == Type.list)
            {
                return val.list.asTag;
            }
            else if (type == Type.dict)
            {
                return val.dict.asTag;
            }
            else if (type == Type.grid)
            {
                return Tag(val.grid.asTag);
            }
            else
            {
                return Tag.init;
            }
        }

        enum Type { scalar, list, dict, grid }
        Type type;

        this(Tag tag)
        {
            state = AnyTagState.ok;
            val.scalar = tag;
            type = Type.scalar;
        }

        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!empty)
                popFront();
            else
                state = AnyTagState.fault;
        }

    private:
        @disable this(this);

        Parser* parser = void;
        Val val;
        enum AnyTagState { scalar, list, dict, grid, ok, fault }
        AnyTagState state;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser("T");
            auto el = Parser.AnyTag(parser);
            assert(el.asTag == true.tag);
        }
        {
            auto parser = Parser("99");
            auto el = Parser.AnyTag(parser);
            assert(el.asTag == 99.tag);
        }
    }

    /// A list of $(D AnyTag)s
    struct TagList
    {
        @property bool empty()
        {
            return state == TagListState.ok
                || state == TagListState.fault;
        }

        @property ref AnyTag front()
        {
            return *val;
        }

        void popFront()
        {
            for(; !empty; parser.lexer.popFront())
            {
                if (parser.isWs)
                    continue;
                eval:
                switch(state)
                {
                    case TagListState.begin:
                        if (!parser.hasChr('['))
                            state = TagListState.fault;
                        else
                        {
                            state++;
                            continue;
                        }
                        return;

                        case TagListState.tag:
                            if (parser.hasChr(']'))
                            {
                                if (val.isNull)
                                    val = Own!AnyTag(Tag());
                                state = TagListState.ok;
                                parser.lexer.popFront();
                            }
                            else if (parser.hasChr(','))
                            {
                                continue;
                            }
                            else
                            {
                                val = Own!AnyTag(*parser);
                                state++;
                            }
                            return;
                        
                        case TagListState.consume:
                            if (!val.consume())
                                state = TagListState.fault;
                            state = TagListState.tag;
                            goto eval;
                        
                    default:
                        break;
                }
            }
        }

        bool consume()
        {
            for(; !empty; popFront()) {}
            return state == TagListState.ok;
        }

        Tag asTag()
        {
            import std.array : appender;
            auto tagList = appender!(Tag[])();
            for(; !empty; popFront()) 
            {
                tagList.put(front.asTag);
            }
            return Tag(tagList.data);
        }

    private:
        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!empty)
                popFront();
            else
                state = TagListState.ok;
        }
        @disable this();
        @disable this(this);
        
        Parser* parser = void;
        Own!AnyTag val;
        enum TagListState { begin, tag, consume, ok, fault }
        TagListState state;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser("[]");
            auto el = Parser.TagList(parser);
            assert(el.asTag == [].tag);
        }
        {
            auto parser = Parser("[1]");
            auto el = Parser.TagList(parser);
            assert(el.asTag == [1.tag]);
        }
        {
            auto parser = Parser("[1, T]");
            auto el = Parser.TagList(parser);
            assert(el.asTag == [1.tag, true.tag]);
        }
        {
            auto parser = Parser("[@foo, M, [T]]");
            auto el = Parser.TagList(parser);
            assert(el.asTag == [Ref("foo").tag, marker, [true.tag].tag]);
        }
    }

    /// Dictionary of tags
    struct TagDict
    {
        @property bool empty()
        {
            return state == TagDictState.ok
                || state == TagDictState.fault;
        }

        @property ref NameValueList front()
        {
            return *val;
        }

        void popFront()
        {
            for(; !empty; parser.lexer.popFront())
            {
                if (parser.isWs)
                    continue;
                switch(state)
                {
                    case TagDictState.begin:
                        if (!parser.hasChr('{'))
                            state = TagDictState.fault;
                        else
                        {
                            state++;
                            continue;
                        }
                        return;

                    case TagDictState.tag:
                        if (parser.lexer.empty && !parser.hasChr('}'))
                        {
                            state = TagDictState.fault;
                            return;
                        }
                        if (parser.hasChr('}'))
                        {
                            if (val.isNull)
                                state = TagDictState.fault;
                            else
                                state = TagDictState.ok;
                            parser.lexer.popFront();
                            return;
                        }
                        if (!val.isNull)
                        {
                            if (!val.consume())
                                state = TagDictState.fault;
                        }
                        else
                        {
                            val = Own!NameValueList(*parser, ',');
                        }
                        return;

                   default:
                        break;
                }
            }
        }

        bool consume()
        {
            for(; !empty; popFront()) {}
            return state == TagDictState.ok;
        }

        Tag asTag()
        {
            auto t = val.asTag;
            if (consume())
                return t;
            else
                return Tag.init;
        }

    private:
        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!empty)
                popFront();
            else
                state = TagDictState.ok;
        }
        @disable this();
        @disable this(this);

        Parser* parser = void;
        Own!NameValueList val;
        enum TagDictState { begin, tag, ok, fault }
        TagDictState state;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto parser = Parser("{age:6");
            auto el = Parser.TagDict(parser);
            el.consume();
            assert(el.state == Parser.TagDict.TagDictState.fault);
        }
        {
            auto parser = Parser("{age:6}");
            auto el = Parser.TagDict(parser);
            assert(el.asTag == ["age": 6.tag].tag);
        }
        {
            auto parser = Parser(`{foo:"bar", baz}`);
            auto el = Parser.TagDict(parser);
            assert(el.asTag == ["foo": "bar".tag, "baz": marker].tag);
        }
        {
            auto parser = Parser(`{dict:{dict}`);
            auto el = Parser.TagDict(parser);
            assert(el.asTag == ["dict": ["dict": marker].tag].tag);
        }
        {
            auto parser = Parser(`{list:[T]}`);
            auto el = Parser.TagDict(parser);
            assert(el.asTag == ["list": [true.tag].tag].tag);
        }
        {
            auto parser = Parser(`{list:[{dict}]}`);
            auto el = Parser.TagDict(parser);
            assert(el.asTag == ["list": [["dict":marker].tag].tag].tag);
        }
    }

    /// Grid of tags
    struct TagGrid
    {
        @property bool empty()
        {
            return state == TagGridState.ok
                || state == TagGridState.fault;
        }

        @property ref Parser front()
        {
            return *val;
        }

        void popFront()
        {
            int markCnt = 0;
            for(; !empty; parser.lexer.popFront())
            {
                if (parser.isWs)
                    continue;
                eval:
                switch(state)
                {
                    case TagGridState.begin:
                        if (markCnt < 2)
                        {
                            if (!parser.hasChr('<'))
                            {
                                state = TagGridState.fault;
                                return;
                            }
                            markCnt++;
                            continue;
                        }
                        else
                        {
                            if (parser.isNl)
                            {   
                                parser.lexer.popFront();
                                state++;
                                goto eval;
                            }
                        }
                        state = TagGridState.fault;
                        return;

                    case TagGridState.grid:
                        if (parser.hasChr('>') && val.isNull)
                        {
                            state = TagGridState.fault;
                        }
                        else
                        {
                            val = Own!Parser(parser.range);
                            state++;
                        }
                        return;
                    
                    case TagGridState.end:
                        if (val.state != ParserState.ok)
                        {
                            state = TagGridState.fault;
                            return;
                        }
                        if (markCnt < 2)
                        {
                            // transfer bck the input range
                            if (markCnt == 0)
                                parser.range = val.range;
                            if (!parser.hasChr('>'))
                            {
                                state = TagGridState.fault;
                                return;
                            }
                            markCnt++;
                            continue;
                        }
                        else
                        {
                            state = TagGridState.ok;
                        }
                        return;

                    default:
                        break;
                }
            }
        }

        bool consume()
        {
            for(; !empty; popFront()) {}
            return state == TagGridState.ok;
        }

        Tag asTag()
        {
            Tag t = val.asTag;
            consume();
            return t;
        }

    private:
        this(ref Parser parser)
        {
            this.parser = &parser;
            if (!empty)
                popFront();
            else
                state = TagGridState.ok;
        }
        @disable this();
        @disable this(this);

        Parser* parser = void;
        Own!Parser val;
        enum TagGridState { begin, grid, end, ok, fault }
        TagGridState state;
    }
    unittest
    {
        alias Parser = ZincParser!string;
        {
            auto r =`<<
                ver:"3.0"
                empty
                >>`;
            auto parser = Parser(r);
            auto el = Parser.TagGrid(parser);
            assert(el.asTag == Grid([], [Grid.Col("empty")], Dict.init, "3.0").tag);
        }
        {
            auto r =`<<
                ver:"3.0"
                name
                "foo"
                >>`;
            auto parser = Parser(r);
            auto el = Parser.TagGrid(parser);
            assert(el.asTag == Grid([["name": "foo".tag]], [Grid.Col("name")], Dict.init, "3.0").tag);
        }
    }

    //

    ///////////////////////////////////////////////////
    //
    // Parser internals
    //////////////////////////////////////////////////

private:
    Lexer lexer = void;
    Element element;

    ///////////////////////////////////////////////////
    // Implementation for parsing $(D Element)s 
    ///////////////////////////////////////////////////

    /////////////////////////////////////
    // helper functions
    /////////////////////////////////////

    @property ref const(Token) token()  pure
    {
        return lexer.front();
    }

    bool expectToken()  pure
    {
        return token.isValid;
    }

    bool expectToken(TokenType type)  pure
    {
        return token.type == type;
    }

    bool expectToken(TokenType type, Tag value)
    {
        return token.isOf(type, value);
    }

    dchar chr() pure
    {
        return token.chr;
    }

    bool hasChr(dchar c)  pure
    {
        return token.hasChr(c);
    }

    @property bool isWs()  pure
    {
        return token.isWs;
    }

    @property bool isNl() pure
    {
        return token.isNl;
    }

    bool isScalar()
    {
        return token.isScalar;
    }
}
/// a string based parser
alias ZincStringParser = ZincParser!string;
unittest
{
    import std.exception;

    {
        auto str = `ver: "3.0"
                    empty`;
        auto empty = ZincStringParser(str).asGrid;
        assert(empty.length == 0);
        assert(empty.colNames[0] == "empty");
    }

    {
        auto str = `ver: "3.0"
            empty
            
            `;
        auto empty = ZincStringParser(str).asGrid;
        assert(empty.length == 0);
        assert(empty.colNames[0] == "empty");
    }

    {
        auto str = `ver:"3.0"
                    id, range
                    @writePoint, "today"  `;
        auto grid = ZincStringParser(str).asGrid;
        assert(grid.hasCol("id"));
        assert(grid.hasCol("range"));
        assert(grid.length == 1);
        assert(grid[0]["id"] == Ref("writePoint"));
        assert(grid[0]["range"] == Str("today"));
    }

    {
        auto str = `ver: "3.0" marker num:100
                    col1, col2 str: "str"
                    M,
                    ,"foo"`;
        auto grid = ZincStringParser(str).asGrid;
        // meta
        assert(grid.meta["marker"] == marker);
        assert(grid.meta["num"] == 100.tag);
        // cols
        assert(grid.cols.length == 2);
        assert(grid.cols[0].dis == "col1");
        assert(grid.cols[0].meta is null);
        assert(grid.cols[1].dis == "col2");
        assert(grid.cols[1].meta["str"] == "str".tag);

        // rows
        assert(grid.length == 2);
        assert(grid[0]["col1"] == marker);
        assert(grid[0]["col2"] == Tag.init);
        assert(grid[1]["col1"] == Tag.init);
        assert(grid[1]["col2"] == "foo".tag);
    }

    {
        auto str = `ver: "3.0"
                    col1
                    {foo:T}`;

        auto grid = ZincStringParser(str).asGrid;
        assert(grid.length == 1);
        auto x = grid[0]["col1"].val!Dict;
        assert(grid[0]["col1"] == ["foo": true.tag].tag);
    }

    {
        auto str = `ver:"3.0"
                    id
                    @equip
                    @site

                    `;

        auto grid = ZincStringParser(str).asGrid;
        assert(grid.length == 2);
    }

    {
        auto str = `ver: "3.0"
                    col1
                    <<
                    ver: "3.0"
                    empty
                    >>`;
        auto grid = ZincStringParser(str).asGrid;
        assert(grid.length == 1);
        assert(grid[0]["col1"] == Grid([], [Grid.Col("empty")], Dict.init, "3.0"));
    }
    {
        auto str = `ver: "3.0"
            col1, col2
            <<
            ver: "3.0"
            empty
            >>, T`;
        auto grid = ZincStringParser(str).asGrid;
        assert(grid.length == 1);
        assert(grid.cols.length == 2);
        assert(grid[0]["col1"] == Grid([], [Grid.Col("empty")], Dict.init, "3.0"));
        assert(grid[0]["col2"] == true.tag);
    }
}

void dumpParser(string zinc)
{
    import std.stdio : writeln;
    alias Parser = ZincStringParser;
    auto parser = Parser(zinc);
    for(; !parser.empty; parser.popFront)
    {
        auto el = &parser.front();
        if (el.type == Parser.Element.Type.header)
        {
            for (; !el.header.empty; el.header.popFront)
            {
                auto h = &el.header.front();
                writeln("Grid element name: ", el.type);
                if (h.type == Parser.Header.Type.ver)
                    writeln(h.ver);
                else if (h.type == Parser.Header.Type.tags)
                {
                    for (; !h.tags.empty; h.tags.popFront)
                    {
                        writeln(h.tags.front.asDict());
                    }
                }
            }
        }
        if (el.type == Parser.Element.Type.columns)
        {
            for (; !el.columns.empty; el.columns.popFront)
            {
                auto col = &el.columns.front();
                writeln("Grid element name: ", el.type);
                if (col.type == Parser.Columns.Type.name)
                    writeln(col.name);
                else if (col.type == Parser.Columns.Type.tags)
                {
                    for (; !col.tags.empty; col.tags.popFront)
                    {
                        writeln(col.tags.front.asDict());
                    }
                }
            }
        }
        if (el.type == Parser.Element.Type.rows)
        {
            for (; !el.rows.empty; el.rows.popFront())
            {
                auto tag = &el.rows.front(); 
                writeln("Grid element name: ", el.type);
                writeln(tag.asTag.toStr);
            }
        }
    }
    writeln("Parser state: ", parser.state);
}