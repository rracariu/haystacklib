// Written in the D programming language.
/**
Haystack trio encoder.

Copyright: Copyright (c) 2019, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.trio.encode;
import std.range.primitives : isOutputRange;
import haystack.tag;
import haystack.zinc.encode : toZinc = encode;
import haystack.zinc.tzdata : timeZone;
public import haystack.zinc.encode : SortedKeys;

/**
Encodes `Dict`as a Trio.
Expects an OutputRange as writer.
Returns: the writter OutputRange
*/
ref R encode(R) (auto ref R writer, const(Dict) dict, SortedKeys sorted = SortedKeys.no)
if (isOutputRange!(R, char))
{
    import std.algorithm    : each, sort;
    
    void encodeKeyValue(string key)
    {
        writer.put(key);
        if (dict[key].peek!Marker)
        {
            writer.put("\n");
            return;
        }

        writer.put(':');

        if (dict[key].peek!XStr)
        {
            const xstr = dict.get!XStr(key);
            writer.put(xstr.type);
            writer.put(":\n  ");
            auto padder = PaddingOutput!R(writer);
            padder.put(xstr.val);
            if (padder.lastChar == '\n')
                return;
        }
        else if (dict[key].peek!Grid)
        {
            writer.put("Zinc");
            writer.put(":\n  ");
            auto padder = PaddingOutput!R(writer);
            const grid = dict.get!Grid(key); 
            toZinc(grid, padder, sorted);
        }
        else if (dict[key].peek!Dict)
        {
            toZinc(dict[key], writer, sorted);
        }
        else
        {
            toZinc(dict[key], writer);
        }
        writer.put("\n");
    }

    if (sorted == SortedKeys.no)
        dict.byKey.each!(k => encodeKeyValue(k));
   else
        dict.keys.sort.each!(k => encodeKeyValue(k));
    
    return writer;
}

/**
Encodes Dict to a Trio string
*/
string trio(const(Dict) dict, SortedKeys sorted = SortedKeys.no)
{
    import std.array : appender;
    auto buf = appender!string();
    buf.encode(dict, sorted);
    return buf.data();
}
unittest
{
    assert(trio(["marker":marker()]) == "marker\n");
}

unittest
{   
    string expected =q"{bool:F
coord:C(37.545826,-77.449188)
date:2019-06-14
dateTime:2019-06-14T15:24:00+03:00 Nicosia
marker
na:NA
number:42$
ref:@someId
str:"a string"
time:16:23:03
uri:`/a/b/c`
xstr:XStr:
  xstr content
  foo
}";

    Dict dict =
    [
        "bool":     false.tag,
        "coord":    Coord(37.545826,-77.449188).tag,
        "date":     Date(2019, 6, 14).tag,
        "dateTime": SysTime(DateTime(Date(2019, 6, 14), TimeOfDay(15, 24, 0)), timeZone("Nicosia")).tag,
        "marker":   marker.tag,
        "na":       na.tag,
        "number":   Num(42, "$").tag,
        "ref":      Ref("someId").tag,
        "str":      "a string".tag,
        "time":     Time(16, 23, 3).tag,
        "uri":      Uri(`/a/b/c`).tag,
        "xstr":     XStr("XStr", "xstr content\nfoo").tag,
    ];
    assert(trio(dict, SortedKeys.yes) == expected);
}
unittest
{   
    string expected =q"{dict:{a:"a" b:1}
list:[1,2,"3"]
zinc:Zinc:
  ver:"3.0"
  empty
  
}";

    Dict dict =
    [
        "dict": ["a": "a".tag, "b": 1.tag].tag,
        "list": [1.tag, 2.tag, "3".tag].tag,
        "zinc": Grid().tag,
    ];
    assert(trio(dict, SortedKeys.yes) == expected);
}

// Adds space padding after each line
private struct PaddingOutput(R)
if (isOutputRange!(R, char))
{
    this (scope ref R r) scope
    {
        this.r = &r;
    }

    void put(string str)
    {
        foreach (c; str)
            put(c);
    }

    void put(dchar c)
    {
        if (c != '\n')
            r.put(c);
        else
            r.put("\n  ");

        lastChar = c;
    }

    R* r;
    dchar lastChar;
}