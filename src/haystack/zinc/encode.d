// Written in the D programming language.
/**
Haystack zinc encode.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.encode;
import haystack.tag;
import std.traits           : isSomeChar;
import std.range.primitives : isOutputRange;

///////////////////////////////////////////////////////////////////
//
// Tag Encoding to Zinc
//
///////////////////////////////////////////////////////////////////

/**
Encodes Marker as 'M'.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Marker), auto ref R writer)
if (isOutputRange!(R, char))
{
    writer.put('M');
}
unittest
{
    assert(zinc(Marker()) != "");
    assert(zinc(Marker()) == "M");
}
/**
Encodes Na as 'NA'.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Na), auto ref R writer)
if (isOutputRange!(R, char))
{
    writer.put("NA");
}
unittest
{
    assert(zinc(Na()) == "NA");
    assert(Na().zinc() != "");
}
/**
Encodes Bool as 'T' or 'F'.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Bool) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    writer.put(val ? 'T' : 'F');

}
unittest
{
    assert(zinc(Bool(true)) == "T");
    assert(zinc(Bool(false)) == "F");
    assert(zinc(Bool(true)) != "");
}
/**
Encodes Num as 1, -34, 10_000, 5.4e-45, 9.23kg, 74.2°F, 4min, INF, -INF, NaN.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Num) value, auto ref R writer)
if (isOutputRange!(R, char))
{
    import std.math     : isInfinity, isNaN;
    import std.format   : formattedWrite;

    if (isInfinity(cast(double)value))
    {
        if (value < 0)
            writer.put('-');
        writer.put("INF");
    }
    else if (isNaN(cast(double)value))
    {
        writer.put("NaN");
    }
    else
    {
        formattedWrite(&writer, "%g", value.val);
        if (value.unit.length)
            writer.put(value.unit);
    }
}

unittest
{
    assert(Num(123).zinc() == "123");
    assert(Num(123.4, "s").zinc() == "123.4s");
    assert(Num(1.5e5, "$").zinc() == "150000$");
    assert(Num(1.5e5, "$").zinc() == "150000$");
    assert(Num(1.5e-3, "$").zinc() == "0.0015$");
    assert(Num(-9.9).zinc() == "-9.9");
    assert(Num(double.infinity).zinc() == "INF");
    assert(Num(-1 * double.infinity).zinc() == "-INF");
    assert(Num(double.nan).zinc() == "NaN");
}

/**
Encodes Str as "hello", "foo\nbar\"".
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Str) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    import std.format : formattedWrite;

    writer.put(`"`);
    foreach (dchar c; val)
    {
        if (c < ' ' || c == '"' || c == '\\')
        {
            switch (c)
            {
                case '"':   writer.put(`\"`); break;
                case '\\':  writer.put(`\\`); break;
                case '\b':  writer.put(`\b`); break;
                case '\f':  writer.put(`\f`); break;
                case '\n':  writer.put(`\n`); break;
                case '\r':  writer.put(`\r`); break;
                case '\t':  writer.put(`\t`); break;
                default:
                    writer.put(`\u`);
                    formattedWrite(&writer, "%04x", c);
            }
        }
        else if (c == '$')
        {
            writer.put(`\$`);
        }
        else
        {
            writer.put(c);
        }
    }
    writer.put(`"`);
}
unittest
{
    assert(zinc(Str("abc\n")) == `"abc\n"`);
    assert(zinc(Str("a\nb\tfoo")) == `"a\nb\tfoo"`);
    assert(zinc(Str("\u0bae")) == `"ம"`);
    assert(zinc(Str("\\\"")) == `"\\\""`);
    assert(zinc(Str("$")) == `"\$"`);
    assert(zinc(Str("_ \\ \" \n \r \t \u0011 _")) == `"_ \\ \" \n \r \t \u0011 _"`);
    assert(zinc(Str("unicode char ש")) == `"unicode char ש"`);
}
/**
Encodes Coord as C(74.0000, -77.000)
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Coord) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    import std.format   : formattedWrite;
    writer.put(`C(`);
    formattedWrite(&writer, "%.6f", val.lat);
    writer.put(',');
    formattedWrite(&writer, "%.6f", val.lng);
    writer.put(')');

}
unittest
{
    assert(Coord(37.545826,-77.449188).zinc() == "C(37.545826,-77.449188)");
}

/**
Encodes XStr as Type("value").
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(XStr) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    writer.put(val.type);
    writer.put(`("`);
    writer.put(val.val);
    writer.put(`")`);

}
unittest
{
    assert(XStr("Blob", "1-2").zinc() == `Blob("1-2")`);
}
/**
Encodes Uri as `/a/b/c`.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Uri) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    writer.put("`");
    foreach (size_t i, dchar c; val.val)
    {
        if (c < ' ')
            continue;
        switch(c)
        {
            case '`' :  writer.put("\\`"); break;
            case '\\' :  writer.put(`\\`); break;
            default:
                if (c >= ' ' && c < 127)
                {
                    writer.put(c);
                }
                else
                {
                    writer.put(`\u`);
                    import std.format : formattedWrite;
                    formattedWrite(&writer, "%04x", c);
                }
        }
    }
    writer.put('`');

}
unittest
{
    assert(zinc(Uri(`/a/b/c`)) == "`/a/b/c`");
}
/**
Encodes Ref as @someRef.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Ref) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    writer.put('@');
    writer.put(val.val);

}
unittest
{
    assert(zinc(Ref("aa-bbc")) == "@aa-bbc");
}
/**
Encodes Date as 2016-12-07 (YYYY-MM-DD).
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Date) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    import std.format   : formattedWrite;
    formattedWrite(&writer, "%02d-%02d-%02d", val.year, val.month, val.day);
}
unittest
{
    assert(zinc(Date(2016, 12, 7)) == "2016-12-07");
}
/**
Encodes Time as 08:43:44 (hh:mm:ss.FFF).
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(TimeOfDay) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    import std.format   : formattedWrite;
    formattedWrite(&writer, "%02d:%02d:%02d", val.hour, val.minute, val.second);

}
/// ditto
void encode(R) (auto ref const(Time) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    import std.format   : formattedWrite;
    encode(cast(TimeOfDay)val, writer);
    if (val.millis > 0)
        formattedWrite(&writer, ".%03d", val.millis);

}
unittest
{
    assert(zinc(TimeOfDay(8, 43, 44)) == "08:43:44");
    assert(zinc(Time(8, 43, 44)) == "08:43:44");
    assert(zinc(Time(23, 59, 59, 999)) == "23:59:59.999");
}

/**
Encodes DateTime as 2009-11-09T15:39:00Z.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(DateTime) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    encode(val.date, writer);
    writer.put('T');
    encode(val.timeOfDay, writer);
    writer.put('Z');
}
/**
Encodes SysTime as 2016-13-07T08:56:00-05:00 New_York.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(SysTime) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    import core.time;
    import std.datetime : UTC;
    import std.format   : formattedWrite;
    import haystack.zinc.tzdata;

    encode(cast(Date)val, writer);
    writer.put('T');
    encode(cast(TimeOfDay)val, writer);
    if (val.fracSecs.total!"nsecs" > 0)
        formattedWrite(&writer, ".%03d", val.fracSecs.total!"msecs");
    if (val.timezone == UTC() || getTimeZoneName(val.timezone) == "UTC")
    {
        writer.put('Z');
    }
    else
    {
        import std.math : abs;
        auto offset = val.utcOffset.split!("hours", "minutes")();
        formattedWrite(&writer, "%s%02d:%02d", offset.hours > 0 ? "+" : "-", offset.hours.abs, offset.minutes);
        string tzname = getTimeZoneName(val.timezone);
        assert(tzname.length, "Time zone name can't be empty." ~ val.timezone.stdName);
        writer.put(' ');
        writer.put(tzname);
    }
}
unittest
{
    import core.time;
    import haystack.zinc.tzdata;
    assert(zinc(DateTime(Date(2016, 12, 7), Time(8, 56, 00))) == "2016-12-07T08:56:00Z");
    auto e = SysTime(DateTime(Date(2016, 12, 7), Time(8, 56, 00)), 100.msecs, timeZone("GMT+7")).zinc();
    string tzname = getTimeZoneName(timeZone("GMT+7"));
    assert(e == "2016-12-07T08:56:00.100-07:00 " ~ tzname);
    e = SysTime(DateTime(Date(2016, 12, 7), Time(8, 56, 00)), 100.msecs, timeZone("GMT-7")).zinc();
    tzname = getTimeZoneName(timeZone("GMT-7"));
    assert(e == "2016-12-07T08:56:00.100+07:00 " ~ tzname);
}
/**
Encodes any Tag as zinc.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Tag) val, auto ref R writer, SortedKeys sorted = SortedKeys.no)
if (isOutputRange!(R, char))
{
    import std.variant  : VariantN, This;
    import std.traits   : fullyQualifiedName, moduleName;

    // null value
    if (!val.hasValue)
    {
        writer.put('N');
        return;
    }
    immutable isGrid = val.peek!Grid !is null;
    if (isGrid)
        writer.put("<<\n");
    Tag value = cast(Tag) val;
    import std.variant : visit;
    // encode current value
    value.visit!(
                    (ref Marker v)  => v.encode(writer),
                    (ref Na v)      => v.encode(writer),
                    (ref Bool v)    => v.encode(writer),
                    (ref Num v)     => v.encode(writer),
                    (ref Str v)     => v.encode(writer),
                    (ref Coord v)   => v.encode(writer),
                    (ref XStr v)    => v.encode(writer),
                    (ref Uri v)     => v.encode(writer),
                    (ref Ref v)     => v.encode(writer),
                    (ref Date v)    => v.encode(writer),
                    (ref Time v)    => v.encode(writer),
                    (ref SysTime v) => v.encode(writer),
                    (ref TagList v) => v.encode(writer),
                    (ref Dict v)    => v.encode(writer, DictBraces.yes, sorted),
                    (ref Grid v)    => v.encode(writer, sorted)
                    )();

    if (isGrid)
        writer.put("\n>>");

}
unittest
{
    assert(Tag().zinc() == "N");
    assert("foo bar".tag.zinc() == `"foo bar"`);
}

/**
Encodes TagList as [1, 2, 3].
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(TagList) val, auto ref R writer)
if (isOutputRange!(R, char))
{
    writer.put('[');
    foreach (size_t i, ref tag; val)
    {
        tag.encode(writer);
        if (i < val.length - 1)
            writer.put(',');
    }
    writer.put(']');

}
unittest
{
    auto list = [1.tag, "foo".tag, false.tag];
    assert(list.zinc() == `[1,"foo",F]`);
}

/// Flag for sorting columns names and dictionary keys alphabetically
enum SortedKeys { no, yes }

/// Flag for wrapping zinc dicts in `{}`
enum DictBraces { no, yes }

/**
Encodes Dict as  {dis:"Building" site area:35000ft²}.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Dict) dict,
                auto ref R writer,
                DictBraces useBraces = DictBraces.yes,
                SortedKeys sorted = SortedKeys.no)
if (isOutputRange!(R, char))
{
    if (useBraces == DictBraces.yes)
        writer.put('{');
    
    void encodeEntry(string name, ref const(Tag) value)
    {
        writer.put(name);
        if (!value.peek!Marker)
        {
            writer.put(':');
            value.encode(writer, sorted);
        }
    }
    
    size_t i = 0;
    if (sorted == SortedKeys.no)
    {
        foreach (name, ref value; dict)
        {
            encodeEntry(name, value);
            if (i++ < dict.length - 1)
                writer.put(' ');
        }
    }
    else
    {
        import std.algorithm : sort;
        foreach (key; dict.keys().sort())
        {
            const val = dict[key];
            encodeEntry(key, val);
            if (i++ < dict.length - 1)
                writer.put(' ');
        }
    }
    if (useBraces == DictBraces.yes)
        writer.put('}');
}
unittest
{
    auto dict = ["marker": marker, "num": 42.tag, "str": "a string".tag];
    assert(dict.zinc(SortedKeys.yes) == `{marker num:42 str:"a string"}`);
}

void encodeGridHeader(R)(auto ref const(Dict) meta, auto ref R writer, SortedKeys sorted = SortedKeys.no)
if (isOutputRange!(R, char))
{
    writer.put(`ver:"3.0"`);
    if (meta.length > 0)
    {
        writer.put(' ');
        meta.encode(writer, DictBraces.no, sorted);
    }
    writer.put('\n');
}

/**
Encodes Grid as ver:"3.0" ... .
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
void encode(R) (auto ref const(Grid) grid, auto ref R writer, SortedKeys sorted = SortedKeys.no)
if (isOutputRange!(R, char))
{
    encodeGridHeader(grid.meta, writer, sorted);
    if (grid.length == 0)
    {
        writer.put("empty");
        writer.put('\n');
        return;
    }

    string[] cols = cast(string[]) grid.colNames();
    if (sorted == SortedKeys.yes)
    {
        import std.array        : array;
        import std.algorithm    : sort;
        cols = cols.sort().array();
    }

    foreach (size_t i, col; cols)
    {
        writer.put(col);
        if (i < cols.length - 1)
            writer.put(',');
    }
    writer.put('\n');
    foreach (size_t rowCnt, ref immutable row; grid)
    {
        foreach (size_t colCnt, col; cols)
        {
            if (row.has(col) && row[col].hasValue)
                row[col].encode(writer, sorted);
            if (colCnt < cols.length - 1)
                writer.put(',');
        }
        if (rowCnt < grid.length - 1)
            writer.put('\n');
    }
}
unittest
{
    auto expect = "ver:\"3.0\"\n"
                 ~"empty\n";
    auto empty = Grid([]);
    assert(empty.zinc(SortedKeys.yes) == expect);
    // grid of scalars
    auto grid = [
        ["marker": marker, "num": 42.tag, "str": "a string".tag],
        ["marker": marker, "num": 100.tag, "str": "a string".tag]
    ];
    expect = "ver:\"3.0\"\n"
        ~"marker,num,str\n"
        ~`M,42,"a string"` ~ "\n"
        ~`M,100,"a string"`;
    string encoded = Grid(grid).zinc(SortedKeys.yes);
    assert(encoded == expect);
    // list and dict
    grid =  [
        ["list": [1.tag, true.tag].tag],
        ["dict": ["a": 1.tag, "b": marker()].tag]
    ];
    expect = "ver:\"3.0\"\n"
        ~ "dict,list\n"
        ~ ",[1,T]\n"
        ~ "{a:1 b},";
    encoded = Grid(grid).zinc(SortedKeys.yes);
    assert(encoded == expect);
    // grid of compound and scalar
    grid =  [
        ["type":"list".tag, "val": [1.tag, 2.tag, 3.tag].tag],
        ["type":"dict".tag, "val": ["dis": "Dict!".tag, "foo": marker].tag],
        ["type":"grid".tag, "val": Grid([["a": 1.tag, "b": 2.tag], ["a": 3.tag, "b": 4.tag]]).tag],
        ["type":"scalar".tag, "val": "a scalar".tag],
    ];
    expect = "ver:\"3.0\"\n"
        ~"type,val\n"
        ~`"list",[1,2,3]` ~ "\n"
        ~`"dict",{dis:"Dict!" foo}` ~ "\n"
        ~`"grid"`~",<<\n"
        ~"ver:\"3.0\"\n"
        ~"a,b\n"
        ~"1,2\n"
        ~"3,4\n"
        ~`>>` ~ "\n"
        ~`"scalar","a scalar"`;
    encoded = Grid(grid).zinc(SortedKeys.yes);
    assert(encoded == expect);
    // meta
    scope metagrid = Grid([["a":1.tag]], ["foo": marker()]);
    expect = `ver:"3.0" foo` ~"\n"
        ~"a\n"
        ~"1";
    encoded = zinc(metagrid, SortedKeys.yes);
    assert(encoded == expect);
}

/**
Encodes any Tag type to Zinc using the $(D OutputRange)
*/
void zinc(T, R)(auto ref const(T) t, auto ref R writer, SortedKeys sorted = SortedKeys.no)
if (isOutputRange!(R, char))
{
    static if (is (T == TimeOfDay))
    {
        Time(t).encode(writer);
    }
    else static if (is (T == DateTime))
    {
        import std.datetime : UTC;
        SysTime(t, UTC()).encode(writer);
    }
    else static if (is (T : const(Dict)))
    {
        t.encode(writer, DictBraces.yes, sorted);
    }
    else static if (is (T : const(Grid)))
    {
        t.encode(writer, sorted);
    }
    else
    {
        t.encode(writer);
    }
}

/**
Encodes any Tag type to a Zinc string
*/
string zinc(T)(auto ref const(T) t, SortedKeys sorted = SortedKeys.no)
{
    import std.array : appender;
    auto buf = appender!string();
    zinc(t, buf, sorted);
    return buf.data;
}