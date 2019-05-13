// Written in the D programming language.
/**
Haystack utils.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.util;
import std.traits : isSomeChar;
import std.range.primitives : isInputRange,
                              ElementEncodingType;

enum isCharInputRange(Range) = isInputRange!Range && isSomeChar!(ElementEncodingType!Range);

/**
A char range that allows look ahead buffering and can also collect a buffer of items
**/
struct LookAhead(Range)
if (isCharInputRange!Range)
{
    import core.memory              : GC;
    import std.utf                  : byChar, encode; 
    import std.internal.scopebuffer : ScopeBuffer;

    this()(auto ref Range range)
    {
        this._range = range;
        initStash();
    }

    ~this()
    {
        _scratchBuf.free();
    }

    @property bool empty()
    {
        return _range.empty && _scratchSlice.empty;
    }
    
    @property char front()
    {
        if (_scratchSlice.empty)
            return _range.front;
        return _scratchSlice.front;
    }

    void popFront()
    {
        if (_scratchSlice.empty)
            _range.popFront();
        else
            _scratchSlice = _scratchSlice[1 .. _scratchSlice.length];
    }
    /// Save current stash as look ahead buffer
    void save()
    {
        if (!_scratchBuf[].empty)
            _scratchSlice = _scratchBuf[0 .. $];
    }

    /// Buffer current char
    void stash()
    {
        // stashing when there is an active look ahead buffer is a no op
        if (!_scratchSlice.empty)
            return;
        _scratchBuf.put(_range.front);
    }
    /// Buffer a wide char
    void stash(dchar c, bool override_ = false)
    {
        // stashing when there is an active look ahead buffer is a no op
        if (!override_ && !_scratchSlice.empty)
            return;
        
        char[4] parts   = void;
        auto size       = encode(parts, c);
        foreach (i; 0..size)
            _scratchBuf.put(parts[i]);
    }
    /// Get the curent content of the stash
    @property const(char)[] crtStash()
    {
        return _scratchBuf[];
    }
    /// True if stash has items
    @property bool hasStash()
    {
        return !_scratchBuf[].empty;
    }
    /// Commit current stash to a string and re-init stash
    string commitStash()
    {
        char[] buf;
        if (_scratchSlice.length)
        {
            buf = _scratchBuf[0.. $ - _scratchSlice.length].dup();
            _scratchBuf.free();
            _scratchBuf = ScopeBuffer!char();
        }
        else
        {
            buf = _scratchBuf[0..$].dup(); 
            initStash();
        }
        return cast(string) buf;
    }

    /// Clears current stash
    void clearStash()
    {
        _scratchBuf.free();
        initStash();
    }

    /**
    True if suplied string is found in the underlying Input range
    If not found, it allows the `LookAhead` to continue iteration from
    the original position the Input range was when the call was performed.
    */
    bool find(string search, bool keepStash = false)
    {
        import std.range    : chain, refRange;

        if (search.empty)
            return false;
        
        static struct WrapRangePtr
        {
            this(R* r) { this.r = r; }
            @property bool empty() { return (*r).empty; }
            @property char front() { return (*r).front; }
            void popFront() { (*r).popFront(); }
            
            alias R = typeof(_range);
            R* r;
        }
        
        auto bufSlice   = _scratchSlice.byChar();
        auto wholeRange = chain(refRange(&bufSlice), WrapRangePtr(&_range));
        size_t count    = 0;
        while (!wholeRange.empty)
        {
            if (count >= search.length || search[count] != wholeRange.front)
                break;
            if (bufSlice.empty)
                stash(wholeRange.front, true);
            wholeRange.popFront;
            count++;
        }
        bool found = (count == search.length);
        if (!found && hasStash) // keep look ahead buffer
            save();
        else if (!keepStash) // init stash buffer
            clearStash();
        return found;
    }

    @property ref Range range()
    {
        return _range;
    }

    @property void range(ref Range range)
    {
        this._range = range;
    }

    // members
private:

    void initStash()
    {
        _scratchBuf     = ScopeBuffer!char();
        _scratchSlice   = _scratchBuf[];
    }

    // The underlying Input range that is iterated
    Range _range                    = void;
    // A slice on the stash, allows to create a look ahead buffer
    char[] _scratchSlice           = void;
    // Scope buffer used for stashing items
    ScopeBuffer!char _scratchBuf    = void;
}
unittest
{
    alias Buf = LookAhead!string;
    auto buf = Buf("123456789");
    assert(buf.front == '1');
    buf.stash();
    buf.save();
    assert(buf.crtStash == "1");
    buf.popFront();
    assert(buf.front == '1');
    buf.popFront();
    assert(buf.front == '2');
    buf.clearStash();
    foreach (i; 0..3)
    {
        buf.stash();
        buf.popFront();
    }
    assert(buf.crtStash == "234");
    buf.save();
    foreach (i; 0..3)
    {
        assert(buf.front == '0' + i + 2);
        buf.popFront();
    }

    buf = Buf("abc");
    assert(buf.front == 'a');
    buf.stash();
    buf.popFront();
    buf.save();

    assert(!buf.find("a23"));

    assert(buf._scratchSlice == "a");
    assert(buf._scratchBuf[] == "a");

    assert(buf.find("abc", true));
    assert(buf._scratchBuf[] == "abc");
    
    buf = Buf("zy亚");
    assert(buf.find("zy亚", true));

}

///////////////////////////////////////////////////////////////
//
// Non decoding char[] range primitives
//
///////////////////////////////////////////////////////////////

@property char front()(inout(char)[] range)
{
    assert(!range.empty);
    return range[0];
}

@property bool empty()(inout(char)[] range)
{
    return !range.length;
}

@property void popFront(ref inout(char)[] range)
{
    assert(!range.empty);
    range = range[1..$];
}

/**
Owns the type T memory ensuring that it is not copyable
and that T constructed memory is freed and T is destroyed at end of scope.
*/
struct Own(T) if (is (T == struct))
{
    import core.memory      : GC;
    import std.conv         : emplace;
    import std.typecons     : Proxy;
    import std.algorithm    : moveEmplace;
    import std.traits       : hasIndirections, hasMember;
    import core.stdc.stdlib : malloc, free;

    this(T t)
    {
        val = cast(T*) malloc(T.sizeof);
        moveEmplace(t, *val);
        static if (hasIndirections!T)
            GC.addRange(val, T.sizeof);
    }

    this(Args...)(auto ref Args args)
    {
        val = cast(T*) malloc(T.sizeof);
        emplace(val, args);
        static if (hasIndirections!T)
            GC.addRange(val, T.sizeof);
    }

    ~this()
    {
        if (this.val is null)
            return;

        static if (hasMember!(T, "__dtor"))
            val.__dtor();
        free(val);
        GC.removeRange(val);
        destroy(val);
    }

    void opAssign(T)(T o)
    {
        destroy(this);
        val = cast(T*) malloc(T.sizeof);
        moveEmplace(o, *val);
        static if (hasIndirections!T)
            GC.addRange(val, T.sizeof);
    }

    void opAssign(Own!T o)
    {
        destroy(this);
        val = o.val;
        o.val = null;
    }
    
    @property bool isNull() pure const
    {
        return this.val is null; 
    }

    bool opEquals()(auto ref const Own!T other) const
    {
        if (this.isNull || other.isNull)
        {
            if (this.isNull && other.isNull)
                return true;
            return false;
        }
        return *this.val == *other.val;
    }

    static if (hasMember!(T, "toHash"))
    @safe size_t toHash() const nothrow
    {
        if (isNull)
            return 0;
        return (*val).toHash();
    }

    mixin Proxy!val;

private:
    T* val;
    @disable this(this);
}

unittest
{
    import std.algorithm : move;
    struct X
    {
        bool b;
    }

    Own!X x;
    x = Own!X(true);
    assert(x.b);
    Own!X y = Own!X(true); 
    x = y.move();
    assert(y.isNull);
    x.b = false;
    auto z = Own!X(*x.move());
    assert(x.isNull);
    assert(!z.b);

    Own!X w = true;
    Own!X v;

    assert(w != v);

    int i;
    struct C
    {
        this(ref int i)
        {
            ++i;
            ii = &i;
        }

        @disable this();
        @disable this(this);
        
        ~this()
        {
            if (ii !is null)
                --(*ii);
        }
        int* ii;
    }

    {
        Own!C dd = Own!C(i);
        auto c = dd.move();
    }
    assert(i == 0);

    struct S
    {
        union U
        {
            Own!C oc;
            C c;
        }

        U u = void;
        enum Type { o, c }

        Type type;

        ~this()
        {
            if (type == Type.o)
                destroy(u.oc);

            if (type == Type.c)
                destroy(u.c);
        }
    }

    {
        S s;
        s.type  = S.Type.o;
        s.u.oc   = Own!C(i);
    }
    assert(i == 0);

    {
        S s;
        s.type  = S.Type.c;
        s.u.c = C(i);
    }
    assert(i == 0);
}