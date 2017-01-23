// Written in the D programming language.
/**
Haystack filter.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.filter;

import std.algorithm : move;
import std.functional : equalTo, lessThan, greaterThan;
import std.traits : isSomeChar;
import std.range.primitives : empty, isInputRange, ElementEncodingType;

import haystack.tag;
import haystack.zinc.util : Own;
import haystack.zinc.lexer;

/// Filter parsing exception
class FilterException : Exception
{
    this(string msg)
    {
        super(msg);
    }
}

/// A $(D Path) resolver type;
alias Resolver = Tag function(const(Dict), const(string[]));

/**
Haystack filter
*/
struct Filter(Range)
if (isInputRange!Range && isSomeChar!(ElementEncodingType!Range))
{
    alias Lexer = ZincLexer!(Range);

    this(Range r, Resolver resolver = null)
    {
        auto lexer = Lexer(r);
        if (lexer.empty)
            throw InvalidFilterException;
        or = parseOr(lexer);
    }
    @disable this(this);

    bool eval(const(Dict) dict) const
    {
        return or.eval(dict);
    }

private:
    Or or; // start node
    Resolver resolver = null; // callback function for resolving paths
    // parse or expression
    Or parseOr(ref Lexer lexer)
    {
        auto a = parseAnd(lexer);
        for(; !lexer.empty; lexer.popFront())
        {
            if (lexer.front.isWs)
                continue;
            if (lexer.front.isOf(TokenType.id, "or".tag))
            {
                lexer.popFront();
                auto b = parseOr(lexer);
                return Or(move(a), Own!Or.make(move(b.a), move(b.b)));
            }
            else
                break;
        }
        return Or(move(a), Own!Or());
    }

    // parse and expression
    And parseAnd(ref Lexer lexer)
    {
        auto a = parseTerm(lexer);
        for(; !lexer.empty; lexer.popFront())
        {
            if (lexer.front.isWs)
                continue;
            if (lexer.front.isOf(TokenType.id, "and".tag))
            {
                lexer.popFront();
                auto b = parseAnd(lexer);
                return And(move(a), Own!And.make(move(b.a), move(b.b)));
            }
            else
                break;
        }
        return And(move(a), Own!And());
    }

    // parse a term
    Term parseTerm(ref Lexer lexer)
    {
        enum State { parens, has, missing, cmp }
        State state;
        Path crtPath = Path("");
        for(; !lexer.empty; lexer.popFront())
        {
            eval:
            if (lexer.front.isWs)
                continue;
            switch (state)
            {
                case State.parens:
                    if (!lexer.front.hasChr('('))
                    {
                        state++;
                        goto eval;
                    }
                    else
                    {
                        lexer.popFront();
                        auto term = Term.makeOr(parseOr(lexer));
                        if (!lexer.front.hasChr(')'))
                            throw InvalidFilterException;
                        lexer.popFront();
                        return move(term);
                    }

                case State.has:
                    if (!lexer.front.isId)
                    {
                        throw InvalidFilterException;
                    }
                    else
                    {
                        auto name = lexer.front.value!Str;
                        if (name == "not")
                        {
                            state = State.missing;
                            continue;
                        }
                        crtPath = parsePath(lexer);
                        state = State.cmp;
                        goto eval;
                    }
                
                case State.missing:
                    auto path = parsePath(lexer);
                    return Term.makeMissing(Missing(path));

                case State.cmp:
                    auto chr = lexer.front.isChar ?  lexer.front.chr : dchar.init;
                    bool hasEq; 
                    if (chr == '<' || chr == '>' || chr == '=' || chr == '!')
                    {
                        if (lexer.empty)
                             throw InvalidFilterException;
                        lexer.popFront();
                        if (chr == '<' || chr == '>' || chr == '!')
                        {
                            if (lexer.front.hasChr('='))
                            {
                                hasEq = true;
                                lexer.popFront();
                            }
                            if (lexer.empty)
                                throw InvalidFilterException;
                        }
                        for(; !lexer.empty; lexer.popFront())
                        {
                            if (lexer.front.isWs)
                                continue;
                            if (lexer.front.isScalar || lexer.front.type == TokenType.id)
                            {
                                Tag tag = cast(Tag) lexer.front.tag;
                                if (tag.peek!Num !is null)
                                {
                                    auto num = tag.get!Num; 
                                    if (num.isNaN || num.isINF)
                                        throw InvalidFilterException;
                                }
                                if (lexer.front.type == TokenType.id) // parse true - false
                                {
                                    auto id = tag.get!Str;
                                    if (id == "true")
                                        tag = true.tag;
                                    else if (id == "false")
                                        tag = false.tag;
                                    else
                                        throw InvalidFilterException;
                                }
                                lexer.popFront();
                                import std.traits : EnumMembers;
                                string op;
                                foreach (m; EnumMembers!(Cmp.Op))
                                {
                                    if (!hasEq)
                                    {
                                        if(m[0] == chr)
                                        {
                                            op = m;
                                            break;
                                        }
                                    }
                                    else
                                    {
                                        if(m[0] == chr && m[$ - 1] == '=')
                                        {
                                            op = m;
                                            break;
                                        }
                                    }
                                }
                                return Term.makeCmp(Cmp(crtPath, op, tag));
                            }
                            else // invalid term
                                break;
                        }
                        throw InvalidFilterException;
                    }
                    else
                    {
                        return Term.makeHas(Has(crtPath));
                    }

                default:
                    throw InvalidFilterException;
            }
        }
        return Term.makeEmpty();
    }

    // parse a Path
    Path parsePath(ref Lexer lexer)
    {
        import std.array : appender;
        auto buf = appender!(string[])();
        enum State { id, sep }
        State state;
        loop:
        for(; !lexer.empty; lexer.popFront())
        {
            if (lexer.front.isWs)
                continue;
            switch (state)
            {
                case State.id:
                    if (!lexer.front.isId)
                        throw InvalidFilterException;
                    else
                    {
                        auto name = lexer.front.value!Str;
                        buf.put(name.val);
                        state = State.sep;
                    }
                    break;

                case State.sep:
                    if (lexer.front.hasChr('-'))
                    {
                        if (lexer.empty)
                            throw InvalidFilterException;
                        lexer.popFront();
                        if (lexer.front.hasChr('>') && !lexer.empty)
                            state = State.id;
                        else
                            throw InvalidFilterException;
                    }
                    else
                        break loop;
                    break;

                default:
                    throw InvalidFilterException;
            }
        }
        return Path(buf.data, resolver);
    }

    static immutable InvalidFilterException = cast(immutable) new FilterException("Invalid filter imput.");
}

unittest
{
    alias StrFilter = Filter!string;
    
    auto filter = StrFilter("id or bar");
    assert(filter.eval(["id": marker]));
    assert(filter.eval(["bar": marker]));

    filter = StrFilter("not bar");
    assert(filter.eval(["id": marker]));
    assert(!filter.eval(["bar": marker]));

    filter = StrFilter("test = true");
    assert(filter.eval(["test": true.tag]));

    try
    {
        filter = StrFilter("test = ");
        assert(filter.eval(["test": true.tag]));
    }
    catch(Exception e)
    {
        
    }

    filter = StrFilter("age = 6");
    assert(filter.eval(["age": 6.tag]));
    assert(!filter.eval(["bar": marker]));

    filter = StrFilter("age = 6 and foo");
    assert(filter.eval(["age": 6.tag, "foo": marker]));

    filter = StrFilter("(age and foo)");
    assert(filter.eval(["age": 6.tag, "foo": marker]));

    filter = StrFilter(`name = "foo bar"`);
    assert(filter.eval(["name": "foo bar".tag]));

    filter = StrFilter(`name >= "foo bar"`);
    assert(filter.eval(["name": "foo bar".tag]));

    filter = StrFilter(`a and b or foo`);
    assert(filter.eval(["foo": marker]));

    filter = StrFilter(`a or b or foo`);
    assert(filter.eval(["foo": marker]));

    filter = StrFilter(`a and b and c`);
    assert(filter.eval(["a": marker, "b": marker, "c": marker]));

    filter = StrFilter(`a and b and c or d`);
    assert(filter.eval(["d": marker]));

    filter = StrFilter(`(a or b) and c`);
    assert(filter.eval(["b": marker, "c": marker]));
}

/**
Or condition
*/
struct Or
{
    And a;
    Own!Or b;

    this(And a, Own!Or b)
    {
        this.a = move(a);
        this.b = move(b);
    }

    @disable this(this);

    bool eval(const(Dict) dict) const
    {
        assert(a.isValid, "Invalid 'or' experssion.");
        if (!(cast(Or) this).b.isNull)
            return a.eval(dict) || b.eval(dict);
        else return a.eval(dict);
    }
}

/**
And condition
*/
struct And
{
    Term a;
    Own!And b;

    this(Term a, Own!And b)
    {
        this.a = move(a);
        this.b = move(b);
    }

    @disable this(this);

    @property bool isValid() const
    {
        return a.isValid;
    }

    bool eval(const(Dict) dict) const
    {
        assert(a.isValid, "Invalid 'and' expression.");
        if (!(cast(And) this).b.isNull && b.isValid)
            return a.eval(dict) && b.eval(dict);
        else return a.eval(dict);
    }
}

/**
A filter term
*/
struct Term
{
    enum Type 
    {
        or,
        has,
        missing,
        cmp,
        empty = uint.max
    }

    Type type = Type.empty;

    @property bool isValid() const
    {
        return type != Type.empty;
    }

    static Term makeOr(Or or)
    {
        auto term = Term(Type.or);
        term.or = Own!Or.make(move(or.a), move(or.b));
        return term;
    }

    static Term makeHas(Has has)
    {
        auto t = Term(Type.has);
        t.has = has;
        return t;
    }

    static Term makeMissing(Missing missing)
    {
        auto t = Term(Type.missing);
        t.missing = missing;
        return t;
    }

    static Term makeCmp(Cmp cmp)
    {
        auto t = Term(Type.cmp);
        t.cmp = cmp;
        return t;
    }

    static Term makeEmpty()
    {
        return Term(Type.empty);
    }
    
    bool eval(const(Dict) dict) const
    {
        final switch (type)
        {
            case Type.or:
                return or.eval(dict);
            case Type.has:
                return has.eval(dict);
            case Type.missing:
                return missing.eval(dict);
            case Type.cmp:
                return cmp.eval(dict);
            case Type.empty:
                return false;
        }
    }

    this(Type type)
    {
        this.type = type;
    }

private:

    @disable this();
    @disable this(this);

    Own!Or or = void;
    union
    {
        Has has = void;
        Missing missing = void;
        Cmp cmp = void;
    }
}

/**
A filter path.
Can be a simple path that resolves to a dict,
or a chained path that resolves across multiple dicts
*/
struct Path
{
    this (string name)
    {
        this.path = [name];
    }

    this (string[] path, Resolver resolver = null)
    {
        this.path = path;
        this.resolver = resolver;
    }
    @disable this();

    Tag resolve(const(Dict) dict) const
    {
        if (path.length == 1)
            return dictResolver(dict, path);
        else if (resolver !is null)
            return resolver(dict, path);
        else return Tag.init;
    }

    string[] path;
    
private:
    Resolver resolver;
    Tag dictResolver(const(Dict) dict, const(string[])) const
    {
        if (path == null || path.length == 0 || path[0].length == 0)
            return Tag.init;
        return dict.get(path[0], Tag.init);
    }
}

///////////////////////////////////////////////////////////////
// Basic predicates
///////////////////////////////////////////////////////////////

/**
Dict has the path
*/
struct Has
{
    this(string path)
    {
        this.path = Path(path);
    }

    this(Path path)
    {
        this.path = path;
    }
    @disable this();

    bool eval(const(Dict) dict) const
    {
        return path.resolve(dict) != Tag.init;
    }

    @property Dict tags()
    {
        return [path.path[0]: marker];
    }
    
private:
    Path path;
}
unittest
{
    auto has = Has("foo");
    assert(has.eval(["foo":marker]));
    assert(has.tags == ["foo":marker]);
}

/**
Dict missing the path
*/
struct Missing
{
    this(string path)
    {
        this.path = Path(path);
    }

    this(Path path)
    {
        this.path = path;
    }
    @disable this();

    bool eval(const(Dict) dict) const
    {
        return !has.eval(dict);
    }
    alias has this;
    Has has;
}
unittest
{
    auto missing = Missing("foo");
    assert(missing.eval(["bar": marker]));
    assert(missing.tags == ["foo": marker]);
}

/**
Dict has the path that satisfies the predicate
*/
struct Cmp
{
    enum Op : string
    {
        eq = "=",
        notEq = "!=",
        less = "<",
        lessOrEq = "<=",
        greater = ">",
        greaterOrEq = ">="
    }

    this(string path, string op, Tag val)
    {
        this(Path(path), cast(Op) op, val);
    }

    this(Path path, string op, Tag val)
    {
        this(path, cast(Op) op, val);
    }

    this(Path path, Op op, Tag val)
    {
        this.path = path;
        this.op = op;
        this.val = val;
    }
    @disable this();

    bool eval(const(Dict) dict) const
    {
        auto v = path.resolve(dict);
        return predicate(v);
    }

    @property Dict tags()
    {
        foreach(Type; Tag.AllowedTypes)
        {
            Type t = Type.init;
            if(typeid(Type) == val.type)
                return [path.path[$ - 1]: Tag(t)];
        }
        return [path.path[$]: marker];
    }

private:

    bool predicate(ref const(Tag) t) const
    {
        final switch(op)
        {
            case Op.eq:
                return equalTo(val, t);
            case Op.notEq:
                return !equalTo(val, t);
            case Op.less:
                return lessThan(val, t);
            case Op.lessOrEq:
                return lessThan(val, t) || equalTo(val, t); 
            case Op.greater:
                return greaterThan(val, t);
            case Op.greaterOrEq:
                return greaterThan(val, t) || equalTo(val, t);
        }
    }

    Path path;
    Op op;
    Tag val;
}
unittest
{
    auto cmp = Cmp("val", "=", true.tag);
    assert(cmp.eval(["val": true.tag]));
    assert(cmp.tags == ["val": Bool.init.tag]);
    
    cmp = Cmp("val", "!=", true.tag);
    assert(cmp.eval(["val": false.tag]));

    cmp = Cmp("val", "<", false.tag);
    assert(cmp.eval(["val": true.tag]));

    cmp = Cmp("val", "<", false.tag);
    assert(cmp.eval(["val": true.tag]));

    cmp = Cmp("val", "=", 1.tag);
    assert(cmp.eval(["val": 1.tag]));

    cmp = Cmp("val", "!=", 1.tag);
    assert(cmp.eval(["val": 0.tag]));

    cmp = Cmp("val", "<", 100.tag);
    assert(cmp.eval(["val": 999.tag]));

    cmp = Cmp("val", "<=", 100.tag);
    assert(cmp.eval(["val": 100.tag]));

    cmp = Cmp("val", ">", 100.tag);
    assert(cmp.eval(["val": 99.tag]));

    cmp = Cmp("val", ">=", 99.tag);
    assert(cmp.eval(["val": 99.tag]));

    cmp = Cmp("val", ">=", "foo".tag);
    assert(cmp.eval(["val": "foo".tag]));

    cmp = Cmp("val", "<", "fo".tag);
    assert(cmp.eval(["val": "foo".tag]));
}