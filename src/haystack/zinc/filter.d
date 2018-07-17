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
    immutable this(string msg)
    {
        super(msg);
    }
}

/// An empty resolver
alias EmptyResolver = Path.emptyResolver!Dict;

/// The default string based haystack filter
alias HaystackFilter = Filter!string;

/**
Haystack filter
*/
struct Filter(Range)
if (isInputRange!Range && isSomeChar!(ElementEncodingType!Range))
{
    alias Lexer = ZincLexer!(Range);

    this(Range r)
    {
        auto lexer = Lexer(r);
        if (lexer.empty)
            throw InvalidFilterException;
        or = parseOr(lexer);
    }
    @disable { this(); this(this); }

    bool eval(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        return or.eval(obj, resolver);
    }

    size_t toHash() const nothrow
    {
        return or.toHash();
    }

    bool opEquals(ref const(Filter) other) const nothrow
    {
        return or == other.or;
    }

private:
    Or or; // start node
    // parse or expression
    Or parseOr(ref Lexer lexer, bool group = false)
    {
        auto a = parseAnd(lexer);
        for(; !lexer.empty; lexer.popFront())
        {
            if (lexer.front.isWs)
                continue;
            if (lexer.front.isOf(TokenType.id, "or".tag))
            {
                lexer.popFront();
                auto b = parseOr(lexer, group);
                return Or(move(a), move(b));
            }
            else if (lexer.front.isChar && !group)
            {
                throw InvalidFilterException;
            }
            else
            {
                break;
            }
        }
        return Or(move(a));
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
                return And(move(a), move(b));
            }
            else
            {
                break;
            }
        }
        return And(move(a));
    }

    // parse a term
    Term parseTerm(ref Lexer lexer)
    {
        enum State { parens, has, missing, cmp }
        State state;
        Path crtPath = void;
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
                        state   = State.has;
                        goto eval;
                    }
                    else
                    {
                        lexer.popFront();
                        auto term = Term(parseOr(lexer, true));
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
                    return Term(Missing(path));

                case State.cmp:
                    auto chr = lexer.front.isChar ?  lexer.front.chr : dchar.init;
                    bool hasEq; 
                    if (chr == '<' || chr == '>' || chr == '=' || chr == '!')
                    {
                        if (lexer.empty)
                             throw InvalidFilterException;
                        lexer.popFront();
                        if (chr == '<' || chr == '>' || chr == '!' || chr == '=')
                        {
                            if (lexer.front.hasChr('='))
                            {
                                hasEq = true;
                                lexer.popFront();
                            }
                            if (lexer.empty || (chr == '=' && !hasEq))
                                throw InvalidFilterException;
                        }
                        for(; !lexer.empty; lexer.popFront())
                        {
                            if (lexer.front.isWs)
                                continue;
                            if (lexer.front.isScalar || lexer.front.type == TokenType.id)
                            {
                                Tag tag = cast(Tag) lexer.front.tag;
                                if (tag.peek!Num)
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
                                        if (m[0] == chr)
                                        {
                                            op = m;
                                            break;
                                        }
                                    }
                                    else
                                    {
                                        if (m[0] == chr && m[$ - 1] == '=')
                                        {
                                            op = m;
                                            break;
                                        }
                                    }
                                }
                                return Term(Cmp(crtPath, op, tag));
                            }
                            else // invalid term
                                break;
                        }
                        throw InvalidFilterException;
                    }
                    else
                    {
                        return Term(Has(crtPath));
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
        return Path(buf.data);
    }

    static InvalidFilterException = new immutable FilterException("Invalid filter input.");
}

unittest
{
    alias StrFilter = Filter!(string);
    
    auto filter = StrFilter("id or bar");
    assert(filter.eval(["id": marker], &EmptyResolver));
    assert(filter.eval(["bar": marker], &EmptyResolver));

    filter = StrFilter("not bar");
    assert(filter.eval(["id": marker], &EmptyResolver));
    assert(!filter.eval(["bar": marker], &EmptyResolver));

    filter = StrFilter("test == true");
    assert(filter.eval(["test": true.tag], &EmptyResolver));

    import std.exception : assertThrown;
    assertThrown(StrFilter("test = ").eval(["foo": marker], &EmptyResolver));
    assertThrown(StrFilter("test('call')").eval(["null": marker], &EmptyResolver));
    

    filter = StrFilter("age == 6");
    assert(filter.eval(["age": 6.tag], &EmptyResolver));
    assert(!filter.eval(["bar": marker], &EmptyResolver));

    filter = StrFilter("age == 6 and foo");
    assert(filter.eval(["age": 6.tag, "foo": marker], &EmptyResolver));

    filter = StrFilter("(age and foo)");
    assert(filter.eval(["age": 6.tag, "foo": marker], &EmptyResolver));

    filter = StrFilter(`name == "foo bar"`);
    assert(filter.eval(["name": "foo bar".tag], &EmptyResolver));

    filter = StrFilter(`name >= "foo bar"`);
    assert(filter.eval(["name": "foo bar".tag], &EmptyResolver));

    filter = StrFilter(`a and b or foo`);
    assert(filter.eval(["foo": marker], &EmptyResolver));

    filter = StrFilter(`a or b or foo`);
    assert(filter.eval(["foo": marker], &EmptyResolver));

    filter = StrFilter(`a and b and c`);
    assert(filter.eval(["a": marker, "b": marker, "c": marker], &EmptyResolver));

    filter = StrFilter(`a and b and c or d`);
    assert(filter.eval(["d": marker], &EmptyResolver));

    filter = StrFilter(`(a or b) and c`);
    assert(filter.eval(["b": marker, "c": marker], &EmptyResolver));
}

/**
Or condition
*/
struct Or
{
    And a;
    Own!Or b;

    this(And a)
    {
        this.a = move(a);
    }

    this(And a, Or b)
    {
        this.a = move(a);
        this.b = move(b);
    }

    @disable this(this);

    bool eval(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        assert(a.isValid, "Invalid 'or' experssion.");
        if (!b.isNull)
            return a.eval(obj, resolver) || b.eval(obj, resolver);
        else 
            return a.eval(obj, resolver);
    }
    
    size_t toHash() const nothrow @trusted
    {
        enum prime  = 31;
        size_t hash = prime * a.toHash();
        return prime * hash + (b.isNull ? 0 : b.toHash());
    }

    bool opEquals(ref const(Or) other) const nothrow
    {
        return a == other.a && b == other.b;
    }
}

/**
And condition
*/
struct And
{
    Term a;
    Own!And b;

    this(Term a)
    {
        this.a = move(a);
    }

    this(Term a, And b)
    {
        this.a = move(a);
        this.b = move(b);
    }

    @disable this(this);

    @property bool isValid() const
    {
        return a.isValid;
    }

    bool eval(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        assert(a.isValid, "Invalid 'and' expression.");
        if (!b.isNull && b.isValid)
            return a.eval(obj, resolver) && b.eval(obj, resolver);
        else 
            return a.eval(obj, resolver);
    }

    size_t toHash() const nothrow
    {
        enum prime  = 31;
        size_t hash = prime * a.toHash();
        return prime * hash + (b.isNull ? 0 : b.toHash());
    }

    bool opEquals(ref const(And) other) const nothrow
    {
        return a == other.a && b == other.b;
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
        empty
    }

    this(Or or)
    {
        type    = Type.or;
        val.or  = or.move();
    }

    this(Has has)
    {
        type    = Type.has;
        val.has = has;
    }

    this(Missing missing)
    {
        type        = Type.missing;
        val.missing = missing;
    }

    this(Cmp cmp)
    {
        type    = Type.cmp;
        val.cmp = cmp;
    }

    static Term makeEmpty()
    {
        return Term(Type.empty);
    }
    
    bool eval(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        final switch (type)
        {
            case Type.or:
                return val.or.eval(obj, resolver);
            case Type.has:
                return val.has.eval(obj, resolver);
            case Type.missing:
                return val.missing.eval(obj, resolver);
            case Type.cmp:
                return val.cmp.eval(obj, resolver);
            case Type.empty:
                return false;
        }
    }

    size_t toHash() const nothrow
    {
        final switch (type)
        {
            case Type.or:
                return val.or.toHash();
            case Type.has:
                return val.has.toHash();
            case Type.missing:
                return val.missing.toHash();
            case Type.cmp:
                return val.cmp.toHash();
            case Type.empty:
                return 31;
        }
    }

    bool opEquals(ref const(Term) other) const nothrow
    {
        if (other.type != type)
            return false;

        final switch (type)
        {
            case Type.or:
                return val.or == other.val.or;
            case Type.has:
                return val.has == other.val.has;
            case Type.missing:
                return val.missing == other.val.missing;
            case Type.cmp:
                return val.cmp == other.val.cmp;
            case Type.empty:
                return true;
        }
    }

    @property bool isValid() const
    {
        return type != Type.empty;
    }
    
    ~this()
    {
        final switch (type)
        {
            case Type.or:
                val.or.destroy(); break;
            case Type.has:
                val.has.destroy(); break;
            case Type.missing:
                val.missing.destroy(); break;
            case Type.cmp:
                val.cmp.destroy(); break;
            case Type.empty:
                break;
        }
    }

private:

    @disable this();
    @disable this(this);

    this(Type type)
    {
        this.type = type;
    }

    union Val
    {
        Own!Or or       = void;
        Has has         = void;
        Missing missing = void;
        Cmp cmp         = void;
    }
    
    Type type   = Type.empty;
    Val val     = void;
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
        this._segments = [name];
    }

    this(string[] segments)
    {
        this._segments = segments;
    }
    @disable this();

    Tag resolve(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        import std.traits : Unqual, isAssociativeArray, KeyType, ValueType;

        static if (isAssociativeArray!Obj)
            alias Type = Unqual!(ValueType!Obj)[Unqual!(KeyType!Obj)];
        else
            alias Type = Unqual!Obj;
        
        static if (is(Type : Dict))
        {
            if (segments.length == 1)
                return dictResolver(obj);
            else if (resolver !is null)
                return resolver(obj, this);
            else 
                return Tag.init;
        }
        else
        {
            if (segments.length == 0 || segments[0].length == 0)
                return Tag.init;
            return resolver(obj, this);
        }
    }
    
    @property ref const(string[]) segments() const
    {
        return _segments;
    }

    static Tag emptyResolver(Obj)(Obj, ref const(Path))
    {
        return Tag.init;
    }

    size_t toHash() const nothrow
    {
        enum prime  = 31;
        size_t hash = prime;
        foreach (seg; _segments)
            foreach (c; seg)
                hash = (hash * prime) + c;
        return hash;
    }

    bool opEquals(ref const(Path) other) const nothrow
    {
        return _segments == other._segments;
    }
    
private:
    Tag dictResolver(const(Dict) dict) const
    {
        if (segments.length == 0 || segments[0].length == 0)
            return Tag.init;
        return dict.get(segments[0], Tag.init);
    }

    string[] _segments;
}
unittest
{
    auto path = Path("test");
    auto dictResolver = &Path.emptyResolver!Dict;
    assert(path.resolve(["test": marker], dictResolver) == marker);
    auto range = ["test": marker].byKeyValue();
    Tag rangeResolver (typeof(range) obj, ref const(Path) path)
    {
        import std.algorithm : find;
        return obj.find!(kv => kv.key == path.segments[0]).front.value;
    }
    assert(path.resolve(range, &rangeResolver) == marker);

    Dict equip = ["id":"equip".tag, "name": "foobar".tag];
    
    Tag resolver(ref const(Dict) dict, ref const(Path) path)
    {
        foreach(i, ref p; path.segments)
        {
            if (i == 0)
            {
                if (!dict.has(p) || equip["id"] != dict[p])
                    break;
            }
            if (i == 1)
            {
                return equip.get(p, Tag.init);
            }
        }

        return Tag.init;
    }
    path = Path(["equipRef", "name"]);
    assert(path.resolve(["equipRef": "equip".tag], &resolver) == "foobar".tag);

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

    bool eval(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        return path.resolve(obj, resolver).hasValue;
    }

    @property Dict tags()
    {
        return [path.segments[0]: marker];
    }

    size_t toHash() const nothrow
    {
        return 31 * path.toHash();
    }

    bool opEquals(ref const(Has) other) const nothrow
    {
        return path == other.path;
    }
    
private:
    Path path;
}
unittest
{
    auto has = Has("foo");
    assert(has.eval(["foo":marker], &EmptyResolver));
    assert(has.tags == ["foo":marker]);
}

/**
Dict missing the path
*/
struct Missing
{
    this(string path)
    {
        this.has = Path(path);
    }

    this(Path path)
    {
        this.has = path;
    }
    @disable this();

    bool eval(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        return !has.eval(obj, resolver);
    }

    alias has this;
    Has has;
}
unittest
{
    auto missing = Missing("foo");
    assert(missing.eval(["bar": marker], &EmptyResolver));
    assert(missing.tags == ["foo": marker]);
}

/**
Dict has the path that satisfies the predicate
*/
struct Cmp
{
    enum Op : string
    {
        eq = "==",
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

    bool eval(Obj, Resolver)(Obj obj, Resolver resolver) const
    {
        auto v = path.resolve(obj, resolver);
        return predicate(v);
    }

    @property Dict tags()
    {
        foreach(Type; Tag.AllowedTypes)
        {
            Type t = Type.init;
            if (typeid(Type) == val.type)
                return [path.segments[$ - 1]: Tag(t)];
        }
        return [path.segments[$]: marker];
    }

    size_t toHash() const nothrow
    {
        enum prime  = 31;
        size_t hash = prime * path.toHash();
        foreach (c; op)
            hash = (hash * prime) + c;
        return prime * hash + val.toHash();
    }

    bool opEquals(ref const(Cmp) other) const nothrow
    {
        if (path != other.path || op != other.op)
            return false;
        try
            return val == other.val;
        catch(Exception e)
            return false;
    }

private:

    bool predicate(ref const(Tag) cmp) const
    {
        if (!cmp.hasValue)
            return false;

        final switch(op)
        {
            case Op.eq:
                return equalTo(cmp, val);
            case Op.notEq:
                return !equalTo(cmp, val);
            case Op.less:
                return lessThan(cmp, val);
            case Op.lessOrEq:
                return lessThan(cmp, val) || equalTo(cmp, val); 
            case Op.greater:
                return greaterThan(cmp, val);
            case Op.greaterOrEq:
                return greaterThan(cmp, val) || equalTo(cmp, val);
        }
    }

    Path path;
    Op op;
    Tag val;
}
unittest
{
    auto cmp = Cmp("val", "==", true.tag);
    assert(cmp.eval(["val": true.tag], &EmptyResolver));
    assert(cmp.tags == ["val": Bool.init.tag]);
    
    cmp = Cmp("val", "!=", true.tag);
    assert(cmp.eval(["val": false.tag], &EmptyResolver));

    cmp = Cmp("val", ">", false.tag);
    assert(cmp.eval(["val": true.tag], &EmptyResolver));

    cmp = Cmp("val", ">", false.tag);
    assert(cmp.eval(["val": true.tag], &EmptyResolver));

    cmp = Cmp("val", "==", 1.tag);
    assert(cmp.eval(["val": 1.tag], &EmptyResolver));

    cmp = Cmp("val", "!=", 1.tag);
    assert(cmp.eval(["val": 0.tag], &EmptyResolver));

    cmp = Cmp("val", ">", 100.tag);
    assert(cmp.eval(["val": 999.tag], &EmptyResolver));

    cmp = Cmp("val", "<=", 100.tag);
    assert(cmp.eval(["val": 100.tag], &EmptyResolver));

    cmp = Cmp("val", "<", 100.tag);
    assert(cmp.eval(["val": 99.tag], &EmptyResolver));

    cmp = Cmp("val", ">=", 99.tag);
    assert(cmp.eval(["val": 99.tag], &EmptyResolver));

    cmp = Cmp("val", ">=", "foo".tag);
    assert(cmp.eval(["val": "foo".tag], &EmptyResolver));

    cmp = Cmp("val", ">", "fo".tag);
    assert(cmp.eval(["val": "foo".tag], &EmptyResolver));
}