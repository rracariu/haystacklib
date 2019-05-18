// Written in the D programming language.
/**
Haystack data types.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/

module haystack.tag;
// types that are public imported and part of the API
public import std.datetime  : TimeOfDay;
public import std.datetime  : Date;
public import std.datetime  : DateTime;
public import std.datetime  : SysTime;

import std.traits   : Unqual;

/************************************************************
Any haystack value type.
************************************************************/
struct Tag
{
    import core.exception       : RangeError;
    import haystack.zinc.util   : SumType;
    
    /// This tag allowed types
    enum Type
    {
        Marker,
        Na,
        Bool,
        Number,
        Str,
        XStr,
        Coord,
        Uri,
        Ref,
        Date,
        Time,
        DateTime,
        List,
        Dict,
        Grid
    }

    // Adds the `SumType` traits
    mixin SumType!Type;

    this(Tag tag)
    {
        this.value = tag.value;
        this.curType = tag.curType;
    }
    
    ref Tag opAssign(Tag val) return
    {
        clearCurValue();
        this.curType = val.curType;
        static foreach (T; AllowedTypes)
        {
            if (curType == TagTypeForType!T)
            {
                T t = val.getValueForType!T();
                setValueForType!T(t);
            }
        }
        return this;
    }

    // Auto-generate the consturctors and assign operator
    // for all supported types
    static foreach (T; AllowedTypes)
    {
        this(T t) pure
        {
            setValueForType!T(t);
            this.curType = TagTypeForType!T;
        }

        ref Tag opAssign(T val) return
        {
            clearCurValue();
            setValueForType!T(val);
            this.curType = TagTypeForType!T;
            return this;
        }
    }
    
    /**
    Construct a `Tag` from  a string
    */
    this(string val)
    {
        setValueForType(cast(Str) val);
        this.curType = Type.Str;
    }
    
    /**
    Asigns a string to a `Tag`
    */
    ref Tag opAssign(string val) return
    {
        clearCurValue();
        setValueForType(cast(Str) val);
        this.curType = Type.Str;
        return this;
    }

    /**
    Construct a `Tag` from a double
    */
    this(double val)
    {
        setValueForType(cast(Num) val);
        this.curType = Type.Number;
    }

    /**
    Asigns a double to a `Tag`
    */
    ref Tag opAssign(double val) return
    {
        clearCurValue();
        setValueForType(cast(Num) val);
        this.curType = Type.Number;
        return this;
    }

    /**
    Construct a `Tag` from a bool
    */
    this(bool val)
    {
        setValueForType(cast(Bool) val);
        this.curType = Type.Bool;
    }

    /**
    Asigns a bool to a `Tag`
    */
    ref Tag opAssign(bool val) return
    {
        clearCurValue();
        setValueForType(cast(Bool) val);
        this.curType = Type.Bool;
        return this;
    }


    /**
    Gets the value for the type `T`
    Returns `T.init` if there is not value or the value is not of type `T` 
    */
    T get(T)() pure inout 
    {
        if (!hasValue || curType != TagTypeForType!T)
            return T.init;
        return getValueForType!T();
    }

    /**
    Returns true if there is a value type `T` 
    */
    bool hasValue(T)() inout @safe nothrow
    {
        return curType == TagTypeForType!T;
    }

    /**
    Returns true if there is a value of any type 
    */
    bool hasValue() pure inout @safe nothrow
    {
        return curType != emptyType;
    }

    /**
    Returns the current `Type`
    */
    Type type() pure inout @safe nothrow
    {
        return curType;
    }

    /**
    Returns the current `TagType`
    */
    string toString() inout
    {
        static foreach (T; AllowedTypes)
        {
            if (curType == TagTypeForType!T)
                return getValueForType!T().toString();
       }
        return "";
    }
    
    // Check eqaulity between 2 `Tag`s
    bool opEquals()(auto ref const(Tag) other) const
    {
        if (!this.hasValue && !other.hasValue)
            return true;
        if (this.curType != other.curType)
            return false;

        static foreach (T; AllowedTypes)
        {
            if (curType == TagTypeForType!T)
                return getValueForType!T() == other.getValueForType!T;
        }
        return false;
    }

    // Generate equality operator for all allowed types
    static foreach (T; AllowedTypes)
    {
        bool opEquals()(auto ref const(T) value) const
        {
            if (this.curType != TagTypeForType!T)
                return false;
            return getValueForType!T() == cast() value;
        }
    }

    size_t toHash() pure const @safe nothrow
    {
        if (hasValue)
            return 0;

        static foreach (T; AllowedTypes)
        {
            if (curType == TagTypeForType!T)
            {
                static if (hasMember!(T, "toHash"))
                    return getValueForType!T().toHash();
                else
                    return ()@trusted { return getValueForType!T().hashOf();}();
            }
        }
        return 0;
    }
    
    int opCmp()(auto ref const(Tag) other) const 
    {
        if (!this.hasValue)
            return -1;
        
        if (!other.hasValue)
            return 1;
        
        static foreach (T; AllowedTypes)
        {
            if (curType == TagTypeForType!T)
            {
                auto thisVal = getValueForType!T();
                auto thatVal = other.getValueForType!T();
                static if (hasMember!(T, "opCmp") || is (typeof(thisVal < thatVal)))
                {
                    if (thisVal == thatVal)
                        return 0;
                    else if (thisVal < thatVal)
                        return -1;
                    else
                        return 1;
                }
                else
                {
                    return 0;
                }
            }
        }
        return -1;
    }

    Tag opIndex(size_t index) pure inout
    {
        if (curType == Type.List)
            return getValueForType!List()[index];
        if (curType == Type.Grid)
            return Tag(cast(Tag[string]) getValueForType!Grid()[index]);
        throw new RangeError();
    }

    Tag opIndex(string index) pure inout
    {
        if (curType == Type.Dict)
            return getValueForType!Dict()[index];
        throw new RangeError();
    }

    auto opDispatch(string name, V...)(V vals) if (TypeHasMemeber!name)
    {
        enum hasFunc(T) = hasMember!(T, name) || (is(T == List) && name == "length");
        alias SupportingTypes = Filter!(ApplyRight!(hasFunc), AllowedTypes);

        alias Type = SupportingTypes[0];
        Type t;
        mixin(`alias ReturnType = typeof(t.`~name~`);`);
        
        static foreach (T; SupportingTypes)
        {
            if (curType == TagTypeForType!T)
            {
                auto m = getValueForType!T();
                return mixin("m." ~ name);
            }
        }
        return ReturnType.init;
    }
}

// Aliases for complex `Tag` types
alias List = Tag[];
alias Dict = Tag[string];
alias Grid = GridImpl!(Dict);

/// Implements a simple pattern matching logic
template visit(Funcs...) if (Funcs.length > 0)
{
    auto visit(Self)(auto ref Self tag)
    {
        import std.traits : ReturnType, Parameters;
        
        static foreach (func; Funcs) // iterate all function handlers
        {
            static if (Parameters!func.length) // check if function has paramas
            {{
                alias Return    = Parameters!func; // function return type
                alias Param     = Parameters!(func)[0]; // fist function param type
                
                static foreach (T; Self.AllowedTypes) // iterate all Tag alllowed types
                {
                    static if (is(Param:T)) // check if fist function param is convertible to tag type `T`
                    {
                        if (tag.curType == Self.TagTypeForType!T) // if the tag has a value of the type `T`
                        {
                            auto val = tag.getValueForType!T(); // det the `Tag` value for `T`
                            // call the handler with the current `Tag` value
                            static if (is(Return == void))
                                func(val);
                            else
                                return func(val);
                        }
                    }
                }
            }}
        }
        static if (is(typeof(return) == void))
            return;
        else
            return typeof(return).init;
    }
}
unittest
{
    Tag t;
    t = "a string";
    assert(t.hasValue!Str());

    string str = t.visit!((Str s) => s.val);
    assert(str == "a string");
}

Str toStr()(auto ref const(Tag) tag)
{
    import std.format : format;
    import std.string : lastIndexOf;
    import std.conv : to;
    string tagVal = !tag.hasValue ? "null" : tag.toString();
    string tagType = to!string(tag.type);
    return Str(format("%s(%s)", tagType[tagType.lastIndexOf('.') + 1..$], tagVal));
}

unittest
{
    Tag v;
    assert(!v.hasValue);
    // marker type
    v = Marker();
    assert(v.hasValue);
    assert(v.get!Marker == Marker());
    assert(marker == Marker());
    // bool type
    v = Bool(true);
    assert(v.get!Bool == true);
    assert(v.get!Bool != false);
    assert(v.get!Bool != 42);
    assert(tag(false) != tag(true));
    // num type
    v = Num(1);
    assert(v.get!Num == Num(1));
    assert(v.get!Num == 1);
    v = Num(100.23);
    assert(v.get!Num == 100.23);
    assert(tag(42) == tag(42));
    // str type
    v = Str("foo bar");
    assert(v.get!Str != "");
    assert(v.get!Str == "foo bar");
    assert(tag("abc").get!Str == "abc");
    // ref type
    v = Ref("@baz");
    assert(v.get!Ref != Ref());
    assert(v.get!Ref == Ref("@baz"));
    // list type
    v = [Tag(Str("aa")), Tag(Num(2))];
    assert(v.length == 2);
    assert(v[0] == cast(Str)"aa");
    assert(v[1] == cast(Num)2);

    // dict type
    Dict d;
    d["test"] = cast(Str)"aaa";
    v = d;
    assert(v["test"] == Str("aaa"));

    // grid type
    Dict row1;
    row1["name"] = Str("Alice");
    row1["age"] = Num(20);
    row1["user"] = Marker();
    Dict row2;
    row2["name"] = Str("Bob");
    row2["age"] = Num(22);
    row2["user"] = Marker();
    v = [row1.tag, row2.tag];
    assert(v.length == 2);
}

/**
Creates a Tag from a buildin type.
Returns: Tag
**/
Tag tag(double val, string unit = "")
{ 
    return Tag(Num(val, unit));
}
/// ditto
Tag tag(long val, string unit = "")
{ 
    return Tag(Num(val, unit));
}
unittest
{
    assert(double.infinity.tag == Tag(Num(double.infinity)));
    assert(42.00.tag("C") == Tag(Num(42, "C")));

    assert(12.tag == Tag(Num(12)));
    assert(42.tag("C") == Tag(Num(42, "C")));
}
/// ditto
Tag tag(T:string)(T t)
{
    return Tag(Str(t));
}
unittest
{
    assert("some string tag".tag == Tag(Str("some string tag")));
}
/// ditto
Tag tag(T:bool)(T t)
{
    return Tag(Bool(t));
}
unittest
{
    assert(false.tag == Tag(Bool(false)));
}

/**
Creates a Tag from a Tag allowed type.
Returns: Tag
**/
Tag tag(T)(T t) if (Tag.allowed!(Unqual!T))
{
    return Tag(cast() t);
}
/// ditto
Tag tag(Num n)
{ 
    return Tag(n);
}
/// ditto
Tag tag(List t) pure
{ 
    return Tag(t); 
}
unittest
{
    assert(Ref("1234").tag == Tag(Ref("1234")));
    assert(SysTime(DateTime(2017, 1, 24, 12, 30, 33)).tag == Tag(SysTime(DateTime(2017, 1, 24, 12, 30, 33))));
    assert([1.tag, true.tag].tag == Tag([1.tag, true.tag]));
    assert(["a": "foo".tag].tag == Tag(["a": "foo".tag]));
    assert(Grid([["a": "foo".tag]]) == Tag(Grid([["a": "foo".tag]])));
}
/**
Creates a Marker ($D Tag).
Returns: a Marker Tag
**/
@property Tag marker() pure
{
    return Tag(Marker());
}
unittest
{
    assert(marker == Tag(Marker()));
}
/**
Creates a Na ($D Tag).
Returns: a Na Tag
**/
@property Tag na() pure
{
    return Tag(Na());
}
unittest
{
    assert(na == Tag(Na()));
}

/************************************************************
Marker tags are used to indicate a "type" or "is-a" relationship.
************************************************************/
struct Marker
{
    string toString() const pure nothrow @nogc
    {
        return "M";
    }
}
unittest
{
    auto m = marker();
    assert(m == Marker());
}
/************************************************************
Represents not available for missing data.
************************************************************/
struct Na
{
    string toString() const pure nothrow @nogc
    {
        return "NA";
    }
}
unittest
{
    auto m = marker();
    assert(m != Na());
}
/************************************************************
Holds boolean "true" or "false" values.
************************************************************/
struct Bool
{
    // implicit a bool
    alias val this;
    /// the value
    bool val;

    string toString() const pure nothrow @nogc
    {
        return val ? "true" : "false";
    }

}
unittest
{
    Bool b = cast(Bool) true;
    assert(b);
    assert(b != false);
    assert(b.val != 12);
}
/************************************************************
Holds a numeric 64 bit floating point value
************************************************************/
struct Num
{
    /// the value
    double val;
    // implicit a double
    alias val this;
    /// the unit defined for this number
    string unit;

    this(Num n)
    {
        this.val    = n.val;
        this.unit   = n.unit;
    }

    this(double val, string unit = null)
    {
        this.val    = val;
        this.unit   = unit;
    }

    bool opEquals()(auto ref const(Num) num) const
    {
        return num.val == this.val && num.unit == this.unit;
    }

    bool opEquals(double d) const
    {
        return d == this.val && this.unit == string.init;
    }

    void opAssign(double val)
    {
        this.val = val;
    }

    @property bool isNaN() const
    {
        import std.math : isNaN;
        return val.isNaN;
    }

    @property bool isINF() const
    {
        return val == val.infinity || val == (-1) * val.infinity;
    }

    @property T to(T)() const
    {
        import std.conv : to;
        return to!T(val);
    }

    string toString() const
    {
        import std.conv : to;
        return to!string(val) ~ (unit.length ? " " ~ unit : "");
    }
}
unittest
{
    Num n = 100.0f;
    assert(n == 100.0);
    n += 2;
    assert(n == 102.0);
    Num x = cast(Num) 42;
    assert(x == 42);
    assert(x != 2);
    auto y = Num(21, "cm");
    assert(y.val == 21 && y.unit == "cm");
    auto z = Num(1, "m");
    assert(z != y);
    auto a = Num(12);
    assert(a == 12 && a.unit == string.init);

    a = Num(42, "$");
    auto t = a.tag();
    assert(t.get!(Num).val == 42 && t.get!(Num).unit == "$");

}
/************************************************************
Holds a string value
************************************************************/
struct Str
{
    alias val this; // implicit a string
    /// the value
    string val;

    string toString() const pure nothrow
    {
        return `"` ~ val ~ `"`;
    }
}
unittest
{
    Str s = cast(Str) "some text";
    Str x = Str("aaaa");
    assert(s == "some text");
    assert(s.val == "some text");
    assert(s != "");
    assert(Str("abc") == "abc");
    assert(Str("x") == Str("x"));
}
/************************************************************
Latitude and Longitude global coordinates
************************************************************/
struct Coord
{
    double lat, lng;

    bool opEquals()(auto ref const(Coord) o) const
    {
        import std.math : approxEqual;
        return approxEqual(lat, o.lat, 1e-8, 1e-8) && approxEqual(lng, o.lng, 1e-8, 1e-8);
    }

    string toString() const
    {
        import std.conv : to;
        return "C(" ~ to!string(lat) ~ ", " ~ to!string(lng) ~ ")";
    }
}
unittest
{
    Coord c1 = Coord(37.545826, -77.449188);
    Coord c2 = Coord(37.545826, -77.449187);
    assert(c1.lat == 37.545826);
    assert(c1.lng == -77.449188);
    assert(c1 != c2);
}
/************************************************************
Extended typed string which specifies a type name a string encoding
************************************************************/
struct XStr
{
    /// the type
    string type;
    /// the value
    string val;

    string toString() const pure nothrow
    {
        return type ~ "(" ~ val ~ ")";
    }
}
unittest
{
    scope a = XStr("foo", "bar");
    assert(a.type == "foo" && a.val == "bar");
}

/************************************************************
Holds a Unversial Resource Identifier.
************************************************************/
struct Uri
{
    /// the value
    string val;

    string toString() const
    {
        return "`" ~ val ~ "`";
    }
}
unittest
{
    Uri s = cast(Uri) "/a/b/c";
    assert(s.val != "");
    assert(s == Uri("/a/b/c"));
}
/************************************************************
Holds a Ref value
************************************************************/
struct Ref
{
    /// the value
    string val;
    /// display
    string dis;

    this(string id, string dis = "") pure inout
    {
        this.val = id;
        this.dis = dis;
    }

    /// constructs a Ref with a random UUID and an optional dis
    static immutable(Ref) gen(string dis = "")
    {
        import std.uuid : randomUUID;
        auto uuid = randomUUID();
        auto str = uuid.toString();
        return Ref(str[0 .. 18], dis);
    }

    @property string display() const
    {
        if (dis.length)
            return dis;
        return val;
    }

    size_t toHash() pure const @safe nothrow
    {
        return val.hashOf();
    }

    bool opEquals()(auto ref const typeof(this) other) @safe pure const nothrow
    {
        return val == other.val;
    }

    string toString() const pure nothrow
    {
        return "@" ~ val;
    }

    @property bool empty() pure const nothrow
    {
        return val.length > 0;
    }
}
unittest
{
    Ref r = cast(Ref)"@foo";
    assert (r == Ref("@foo"));
    assert(Ref.gen("xx").display == "xx");
}
/************************************************************
Holds an ISO 8601 time as hour, minute, seconds
and millisecs: 09:51:27.354
************************************************************/
struct Time
{
    TimeOfDay tod;
    int millis;

    this(TimeOfDay tod, int millis = 0)
    {
        this.hour = tod.hour;
        this.minute = tod.minute;
        this.second = tod.second;
        this.millis = millis;
    }

    this(int hour, int minute, int second, int millis = 0)
    {
        this.hour = hour;
        this.minute = minute;
        this.second = second;
        this.millis = millis;
    }

    invariant()
    {
        assert(hour >= 0 && hour <= 23);
        assert(minute >= 0 && minute <= 59);
        assert(second >= 0 && second <= 59);
        assert(millis >= 0 && millis <= 999);
    }

    alias tod this;

    string toString() const pure nothrow
    {
        import std.conv : to;
        return tod.toString ~ "." ~ to!string(millis);
    }
}

unittest
{
    Time t = Time(17, 47, 28, 99);
    assert(t.hour == 17);
    assert(t.minute == 47);
    assert(t.second == 28);
    assert(t.millis == 99);
    import std.exception : assertThrown;
    import core.time : TimeException;
    assertThrown!TimeException(Time(100, 47, 28));
}
/**
Check if Dict is empty.
Returns: true if dict is empty.
*/
@property bool empty(const(Dict) dict) pure nothrow
{ 
    return dict.length == 0;
}

/**
Check if Dict contains column.
Returns: true if dict contains that column.
*/
bool has(const(Dict) dict, string col) pure nothrow 
{ 
    return (col in dict) != null;
}

/**
Check if Dict misses the column.
Returns: true if dict doe not contain the column.
*/
bool missing(const(Dict) dict, string col) pure nothrow
{ 
    return !dict.has(col);
}
unittest
{
    Dict d;
    assert(d.empty);
    d["str"] = Str("a");
    d["num"] = Num(12, "m/s");
    d["num1"] = Num(45);
    d["marker"] = Marker();
    d["bool"] = Bool(true);
    d["aaa"] = cast(Str)"foo";

    assert(d.has("str"));
    assert(d["str"].get!Str == "a");
    assert(d["str"] == Str("a"));
    assert(d["num"] == Num(12, "m/s"));
    assert(d["num1"] == Num(45));
    assert(d["marker"] == Marker());
    assert(d["bool"] == Bool(true));
    assert(d.missing("foo"));
    assert(!d.empty);
}

/**
Gets the 'id' key for the $(D Dict). Returns a $(D Ref.init) otherwise
*/
@property immutable(Ref) id(const(Dict) rec)
{
    return rec.get!Ref("id");
}
unittest
{
    Dict d = ["id": Ref("id").tag];
    assert(d.id == Ref("id"));
    assert(["x": 1.tag].id == Ref.init);
}

/**
Gets the 'dis' property for the $(D Dict).
If the $(D Dict) has no 'id' or no 'dis' then an empty string is returned,
if there is an 'id' property but without a 'dis' the 'id' value is returned.
*/
@property string dis(const(Dict) rec)
{
    auto id = rec.get!Ref("id");
    return id.dis != "" ? id.dis : id.val;
}
unittest
{
    Dict d = ["id": Ref("id", "a dis").tag];
    assert(d.dis == "a dis");
    assert(["id": Ref("id").tag].dis == "id");
    assert(["bad": 1.tag].dis == "");
}
/**
Get $(D Dict) property of type $(D T), or if property is missing $(D T.init)
*/
T get(T)(const(Dict) dict, string key) if (Tag.allowed!T)
{
    if (dict.missing(key))
        return T.init;
    return dict[key].get!T;
}
unittest
{
    Dict d = ["val": Str("foo").tag];
    assert(d.get!Str("val") == "foo");
}
/**
Test if $(D Dict) has property of type $(D T)
*/
bool has(T)(const(Dict) dict, string key) if (Tag.allowed!T)
{
    if (dict.missing(key))
        return false;
    return dict[key].hasValue!T;
}
unittest
{
    Dict d = ["id": Ref("foo").tag, "num": 1.tag];
    assert(d.has!Ref("id"));
    assert(!d.has!Bool("num"));
    assert(d.has!Num("num"));
}

/**
Test if the `Dict` has a `key` of null value

Params:
dict    = the ditionary.
key     = the key to look up 

Returns: true if dict has a null value key.

*/
@property bool isNull(const(Dict) dict, string key)
{
    return dict.has(key) && dict[key] == Tag.init;
}
unittest
{
    Dict d = ["foo": false.tag, "bar": Tag()];
    assert(!d.isNull("id"));
    assert(d.isNull("bar"));
}

/**
Test if $(D Dict) misses property of type $(D T)
*/
bool missing(T)(const(Dict) dict, string key) if (Tag.allowed!T)
{
    return !dict.has!T(key);
}
unittest
{
    Dict d = ["num": 1.tag];
    assert(!d.missing!Num("num"));
    assert(d.missing!Ref("num"));
    assert(d.missing!Bool("foo"));
}

string toString(const(Dict) dict)
{
    import std.array : appender;

    auto buf = appender!(string)();
    auto size = dict.length;
    buf.put('{');
    foreach (entry; dict.byKeyValue)
    {
        buf.put(entry.key);
        buf.put(':');
        buf.put(entry.value.toStr);
        if (--size > 0)
            buf.put(',');
    }
    buf.put('}');
    return buf.data;
}

string toString(const(List) list)
{
    import std.array : appender;

    auto buf = appender!(string)();
    buf.put('[');
    foreach (i, entry; list)
    {
        buf.put(entry.toStr);
        if (i < list.length - 1)
            buf.put(", ");
    }
    buf.put(']');
    return buf.data;
}

/************************************************************
Haystack Grid.
************************************************************/
struct GridImpl(T)
{
    /// Create $(D Grid) from a list of Dict
    this(inout T[] val)
    {
        this(val, T.init);
    }

    /// Create a $(D Grid) from a list of $(D Dict) and a meta data $(D Dict)
    this(T[] val, T meta)
    {
        this._meta = meta;
        this.val = val;
        Col[string] cl;
        foreach(ref row; val)
            foreach (ref col; row.byKey)
                if (col !in cl)
                        cl[col] = Col(col);
        this.columns = cl;
    }

    /// Create  $(D Grid) from const or immutable list of $(D Dict)
    this(const(T[]) val, const(T) meta)
    {
        this(cast(T[])val, cast(T) meta);
    }

    /// Create dict from const or immutable Dict
    this(const(T[]) val, T meta)
    {
        this(cast(T[])val, meta);
    }

    /// Create a $(D Grid) from a list of $(D Dict)s, a list of columns, and a meta data $(D Dict)
    this(const(T[]) val, Col[] cols, T meta = T.init, string ver = "3.0")
    {
        //this.ver = ver;
        this._meta = meta;
        this.val = cast(T[]) val;
        Col[string] cl;
        foreach(ref col; cols)
            cl[col.dis] = col;
        this.columns = cl;
        this.ver = ver;
    }

    /// Create a $(D Grid) from a list of $(D Dict)s, a list of column names, and a meta data $(D Dict)
    this(const(T[]) val, string[] colsNames, T meta = T.init, string ver = "3.0")
    {
        this._meta  = meta;
        this.val    = cast(T[]) val;
        Col[string] cols;
        foreach(colName; colsNames)
            cols[colName] = Col(colName);
        this.columns    = cols;
        this.ver        = ver;
    }

    /// This grid columns
    @property const(Col[]) cols() const
    {
        return columns.values;
    }
    /// This grid columns
    @property const(string[]) colNames() const
    {
        return columns.keys;
    }
    /// Has the column name
    @property bool hasCol(string col) const
    {
        return ((col in columns) !is null);
    }
    /// Mising a column
    @property bool missingCol(string col) const
    {
        return !hasCol(col);
    }

    /// This grid meta data
    @property ref const(T) meta() const
    {
        return _meta;
    }

    /// This grid rows
    @property size_t length() const
    {
        return val.length;
    }

    /// True if the $(D Grid) had no meta and no rows
    @property bool empty() const
    {
        return val.length == 0 && meta.length == 0;
    }

    const(T) opIndex(size_t index) const
    {
        return val[index];
    }

    int opApply(scope int delegate(ref immutable(T)) dg) const
    {
        int result = 0;
        foreach (dict; cast(immutable) val)
        {
            result = dg(dict);
            if (result)
                break;
        }
        return result;
    }

   int opApply(scope int delegate(ref size_t i, ref immutable(T)) dg) const
   {
       int result = 0;
       foreach (i, dict; cast(immutable) val)
       {
           result = dg(i, dict);
           if (result)
               break;
       }
       return result;
   }

   const(T[]) rows() const
   {
       return val;
   }

   /// The column descriptor
   static struct Col
   {
       string dis;
       T meta;

       this(string name, T meta = T.init)
       {
           this.dis = name;
           this.meta = meta;
       }
   }
   string ver = "3.0";

   string toString() const
   {
       import std.array : appender;
       auto buf = appender!(string)();
       buf.put("<\n");
       buf.put("ver: ");
       buf.put(ver);
       buf.put('\n');
       buf.put("meta: ");
       buf.put((cast(Dict) meta).toString);
       buf.put('\n');
       buf.put("[\n");
       foreach (i, row; val)
       {
           buf.put((cast(Dict) row).toString());
           if (i < val.length - 1)
               buf.put(',');
           buf.put('\n');
       }
       buf.put(']');
       buf.put(">\n");
       return buf.data;
    }

   this(immutable typeof(this) other) immutable
   {
        this.val        = other.val;
        this._meta      = other._meta;
        this.columns    = other.columns;
   }

private:
    // Grid storage
    T[] val;
    T _meta;
    Col[string] columns;
}
unittest
{
   // grid type
    Dict row1 = ["name":    tag("Alice"),
                 "age":     tag(20),
                 "user":    marker];
    Dict row2;
    row2["name"] = Str("Bob");
    row2["age"] = Num(22);
    row2["user"] = Marker();
    Grid grid = Grid([row1, row2]);
    assert(grid.cols.length == 3);
    assert(grid.hasCol("name"));
    assert(grid.missingCol("id"));
    foreach(ref rec; grid)
        assert(rec.length == 3);
    Tag t = [tag(1)];
    row1 = ["name": tag([tag(1)])];
    auto grid1 = Grid([row1]);
    assert( grid1[0]["name"][0] == Num(1).tag);
}

/// Make an error $(D Grid)
Grid errorGrid(string message)
{
    return Grid([], ["err" : marker, "dis" : message.tag]);
}
Grid errorGrid(Exception ex)
{
    auto desc = ["err" : marker, "dis" : ex.msg.tag];
    if (ex.info)
        desc["errTrace"] = ex.info.toString.tag;
    return Grid([], desc);
}
unittest
{
    assert(errorGrid(new Exception("an error")).meta["err"] == marker());
}