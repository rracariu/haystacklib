// Written in the D programming language.
/**
Haystack utils.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.util;
import core.stdc.stdlib : malloc, free;
import std.conv : emplace;
import std.typecons : Proxy;
import std.range.primitives : empty, front, popFront;
/**
A char range that allows look ahead buffering and can also collect a buffer of items
**/
struct LookAhead(Range)
{
    this()(auto ref Range r)
    {
        this.r = r;
        clearStash();
    }

    ~this()
    {
        _scratchBuf.free();
    }

    @property bool empty()
    {
        return r.empty && _scratchSlice.empty;
    }
    
    @property dchar front()
    {
        if (_scratchSlice.empty)
            return r.front;
        return _scratchSlice.front;
    }

    void popFront()
    {
        if (_scratchSlice.empty)
        {
            r.popFront();
            position++;
        }
        else
        {
            _scratchSlice = _scratchSlice[1 .. _scratchSlice.length];
        }
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
        stash(r.front);
    }
    /// Buffer a specific char
    void stash(dchar c)
    {
        // stashing when there is an active look ahead buffer is a no op
        if (!_scratchSlice.empty)
            return;

        if (c <= 127)
            _scratchBuf.put(cast(char)c);
        else
        {
            import std.utf : encode;
            char[4] parts = void;
            auto size = encode(parts, c);
            foreach (i; 0..size)
                _scratchBuf.put(parts[i]);
        }
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
        auto buf = _scratchBuf[];
        import core.memory : GC;
        GC.addRange(buf.ptr, buf.length, typeid(buf));
        clearStash();
        return cast(string) buf;
    }
    /// Clears current stash
    void clearStash()
    {
        _scratchBuf = ScopeBuffer!char();
        _scratchSlice = _scratchBuf[];
    }
    /// True if suplied string is found in the underlying Input range
    /// If not found, it allows the StashInput to continue iteration from
    /// the original position the Input range was when the call was performed.
    bool find(string s)
    {
        if (s.empty)
            return false;
        size_t cnt;    
        while(!r.empty)
        {
            if (cnt >= s.length || s[cnt] != r.front)
                break;
            stash(r.front);
            cnt++;
            r.popFront;
        }
        bool found = (cnt == s.length);
        if (!found && hasStash) // keep look ahead buffer
            save();
        else // init stash buffer
            clearStash();
        return found;
    }

    @property ref Range range()
    {
        return r;
    }

    @property void range(ref Range r)
    {
        this.r = r;
    }

    // members
private:
    // The underlying Input range that is iterated
    Range r = void;
    // Char count
    size_t position = -1;
    // A slice on the stash, allows to create a look ahead buffer
    char[] _scratchSlice;
    // Scope buffer used for stashing items
    import std.internal.scopebuffer;
    ScopeBuffer!char _scratchBuf = void;
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
}

/**
Owns the type T memory ensuring that it is not copyable
and that T constructed memory is freed and T is destroyed at end of scope.
*/
struct Own(T)
{
    this(Args...)(auto ref Args args)
    {
        auto mem = cast(T*) malloc(T.sizeof);
        val = emplace!T(mem, args);
    }

    this(Own!T o)
    {
        val = o.val;
        o.val = null;
    }

    ~this()
    {
        if (val !is null)
        {
            import std.traits;
            static if (hasMember!(T, "__dtor"))
                val.__dtor();
            free(val);
            destroy(val);
        }
    }

    /**
    Construct using explicit move semantics
    */
    static Own!T make(Args...)(Args args)
    {
        import std.conv : to;
        string ctorCall(size_t len) // ctfe
        {
            string call = "mem.__ctor(";
            for(size_t i = 0; i < len; i++)
            {
                call ~= "move(args[" ~ to!string(i) ~ "])";
                if (i < len - 1)
                    call ~= ", ";
            }
            call ~= ");";
            return call;
        }
        auto mem = cast(T*) malloc(T.sizeof);
        import std.algorithm : move;
        mixin(ctorCall(args.length));
        return Own!T(mem);
    }

    void opAssign(T)(Own!T o)
    {
        destroy(this);
        val = o.val;
        o.val = null;
    }
    
    @property bool isNull()
    {
        return val is null; 
    }

    mixin Proxy!val;

private:

    this(T* ptr)
    {
        val = ptr;
    }

    T* val = null;
    @disable this(this);
}

unittest
{
    struct X
    {
        bool b;
    }

    Own!X x;
    x = Own!X(true);
    assert(x.b);
    Own!X y = Own!X(true); 
    import std.algorithm : move;
    x = move(y);
    assert(y.val is null);
    auto z = Own!X(move(x));
    assert(x.val is null);

    int i;
    struct C
    {
        this(ref int i)
        {
            ++i;
            ii = &i;
        }
        
        ~this()
        {
            --(*ii);
        }
        int* ii;
    }

    {
        Own!C dd = Own!C(i);
    }
    assert(i == 0);
}