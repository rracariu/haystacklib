// Written in the D programming language.
/**
Timezone realted data and code.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.util.tzdata;

import std.uni      : sicmp;
import std.datetime : TimeZone, UTC;

private string cityName(string fullName) pure
{
    import std.string : lastIndexOf;
    if (fullName.sicmp("STD") == 0)
        return "UTC";
    return fullName[fullName.lastIndexOf('/') + 1 .. $];
}

version(Posix)
{
    import std.datetime : PosixTimeZone;

    immutable bool hasTzData;
    immutable string[string] shortNames;

    shared static this()
    {
        import std.string   : lineSplitter;
        import std.stdio    : writeln;
        try
        {
            if (PosixTimeZone.getInstalledTZNames().length == 0)
            {
                writeln("Warning, no timezone data detected! Falling back to UTC.");
            }
            else
            {
                hasTzData = true;
                // data from https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
                foreach (tzName; import("timzoneList.txt").lineSplitter())
                {
                    shortNames[cityName(tzName)] = tzName;
                }
            }
        }
        catch (Exception e)
        {
            hasTzData = false;
            writeln("Warning, no timezone data detected! Falling back to UTC. Details: ", e);
        }
    }

    static immutable(TimeZone) timeZone(string name)
    {
        if (!hasTzData || name.sicmp("UTC") == 0 || name.sicmp("STD") == 0)
            return UTC();
        if (name.contains('/'))
        {
            return PosixTimeZone.getTimeZone(name);
        }
        else
        {
            const fullName = shortNames[name];
            return PosixTimeZone.getTimeZone(fullName);
        }
    }

    static string getTimeZoneName(immutable(TimeZone) tz)
    {
        return cityName(tz.name.length ? tz.name : tz.stdName);
    }
}

version (Windows)
{
    import std.datetime : WindowsTimeZone,
                          parseTZConversions,
                          TZConversions;

    /**
    Implemenst the `TimeZone` interface by adding the accurate time zone info
    */
    final class HaystackTimeZone : TimeZone
    {
        immutable this(string tzName, immutable(WindowsTimeZone) windowsTz)
        {
            super(windowsTz.name, windowsTz.stdName, windowsTz.dstName);
            this.cityName   = .cityName(tzName);
            _tzName         = tzName;
            _tz             = windowsTz;
        }

        override @property string name() @safe const nothrow
        {
            return _tzName;
        }

        override bool hasDST() const nothrow @property @safe
        {
            return _tz.hasDST();
        }
        
        override bool dstInEffect(long stdTime) const nothrow @safe
        {
            return _tz.dstInEffect(stdTime);
        }
        
        override long utcToTZ(long stdTime) const nothrow @safe
        {
            return _tz.utcToTZ(stdTime);
        }
        
        override long tzToUTC(long adjTime) const nothrow @safe
        {
            return _tz.tzToUTC(adjTime);
        }

        immutable(string) cityName;

    private:
        immutable(string) _tzName;
        immutable(WindowsTimeZone) _tz;
    }

    immutable(TimeZone) timeZone(string name)
    {
        if (name.sicmp("UTC") == 0)
            return UTC();

        if (name in conv.toWindows)
            return new immutable HaystackTimeZone(name, WindowsTimeZone.getTimeZone(conv.toWindows[name][0]));
        else
            return getTimeZone(name);
    }

    string getTimeZoneName(immutable(TimeZone) tz)
    {
        immutable name = tz.name;
        if (!name.length || name == "Coordinated Universal Time")
            return "UTC";
        if (cast(HaystackTimeZone) tz)
            return (cast(HaystackTimeZone) tz).cityName;
        return cityName(name);
    }

    private immutable(TimeZone) getTimeZone(string name)
    {
        immutable tz = name in shortNames;
        return tz !is null ? *tz : null;
    }

    private immutable TZConversions conv;
    private immutable TimeZone[string] shortNames;

    shared static this()
    {
        // Source of the definitions:
        // https://raw.githubusercontent.com/unicode-org/cldr/master/common/supplemental/windowsZones.xml
        conv = parseTZConversions(import("windowsZones.xml"));
        foreach (timeZones; conv.fromWindows.byValue)
        {
            foreach (timeZoneName; timeZones)
            {
                const shortName         = cityName(timeZoneName);
                const windowsTzNames    = conv.toWindows[timeZoneName];
                const windowsTzName     = windowsTzNames[0];
                const windowsTz         = WindowsTimeZone.getTimeZone(windowsTzName);
                const tz                = new immutable HaystackTimeZone(timeZoneName, windowsTz);
                shortNames[shortName]   = tz;
            }
        }
    }
}