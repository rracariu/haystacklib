// Written in the D programming language.
/**
Timezone realted data and code.

Copyright: Copyright (c) 2017, Radu Racariu <radu.racariu@gmail.com>
License:   $(LINK2 www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
Authors:   Radu Racariu
**/
module haystack.zinc.tzdata;

import std.string : toUpper;
import std.datetime : TimeZone, UTC;

private string cityName(string fullName)
{
    import std.string : lastIndexOf;
    return fullName[fullName.lastIndexOf('/') + 1 .. $];
}

version(Posix)
{
    import std.datetime : PosixTimeZone;
    static immutable __gshared string[string] shortNames;
    shared static this()
    { 
        auto tzNames = 
        [
            "Abidjan":"Africa/Abidjan",
            "Accra":"Africa/Accra",
            "Addis_Ababa":"Africa/Addis_Ababa",
            "Algiers":"Africa/Algiers",
            "Asmara":"Africa/Asmara",
            "Asmera":"Africa/Asmera",
            "Bamako":"Africa/Bamako",
            "Bangui":"Africa/Bangui",
            "Banjul":"Africa/Banjul",
            "Bissau":"Africa/Bissau",
            "Blantyre":"Africa/Blantyre",
            "Brazzaville":"Africa/Brazzaville",
            "Bujumbura":"Africa/Bujumbura",
            "Cairo":"Africa/Cairo",
            "Casablanca":"Africa/Casablanca",
            "Ceuta":"Africa/Ceuta",
            "Conakry":"Africa/Conakry",
            "Dakar":"Africa/Dakar",
            "Dar_es_Salaam":"Africa/Dar_es_Salaam",
            "Djibouti":"Africa/Djibouti",
            "Douala":"Africa/Douala",
            "El_Aaiun":"Africa/El_Aaiun",
            "Freetown":"Africa/Freetown",
            "Gaborone":"Africa/Gaborone",
            "Harare":"Africa/Harare",
            "Johannesburg":"Africa/Johannesburg",
            "Juba":"Africa/Juba",
            "Kampala":"Africa/Kampala",
            "Khartoum":"Africa/Khartoum",
            "Kigali":"Africa/Kigali",
            "Kinshasa":"Africa/Kinshasa",
            "Lagos":"Africa/Lagos",
            "Libreville":"Africa/Libreville",
            "Lome":"Africa/Lome",
            "Luanda":"Africa/Luanda",
            "Lubumbashi":"Africa/Lubumbashi",
            "Lusaka":"Africa/Lusaka",
            "Malabo":"Africa/Malabo",
            "Maputo":"Africa/Maputo",
            "Maseru":"Africa/Maseru",
            "Mbabane":"Africa/Mbabane",
            "Mogadishu":"Africa/Mogadishu",
            "Monrovia":"Africa/Monrovia",
            "Nairobi":"Africa/Nairobi",
            "Ndjamena":"Africa/Ndjamena",
            "Niamey":"Africa/Niamey",
            "Nouakchott":"Africa/Nouakchott",
            "Ouagadougou":"Africa/Ouagadougou",
            "Porto-Novo":"Africa/Porto-Novo",
            "Sao_Tome":"Africa/Sao_Tome",
            "Timbuktu":"Africa/Timbuktu",
            "Tripoli":"Africa/Tripoli",
            "Tunis":"Africa/Tunis",
            "Windhoek":"Africa/Windhoek",
            "Adak":"America/Adak",
            "Anchorage":"America/Anchorage",
            "Anguilla":"America/Anguilla",
            "Antigua":"America/Antigua",
            "Araguaina":"America/Araguaina",
            "Buenos_Aires":"America/Argentina/Buenos_Aires",
            "Catamarca":"America/Argentina/Catamarca",
            "ComodRivadavia":"America/Argentina/ComodRivadavia",
            "Cordoba":"America/Argentina/Cordoba",
            "Jujuy":"America/Argentina/Jujuy",
            "La_Rioja":"America/Argentina/La_Rioja",
            "Mendoza":"America/Argentina/Mendoza",
            "Rio_Gallegos":"America/Argentina/Rio_Gallegos",
            "Salta":"America/Argentina/Salta",
            "San_Juan":"America/Argentina/San_Juan",
            "San_Luis":"America/Argentina/San_Luis",
            "Tucuman":"America/Argentina/Tucuman",
            "Ushuaia":"America/Argentina/Ushuaia",
            "Aruba":"America/Aruba",
            "Asuncion":"America/Asuncion",
            "Atikokan":"America/Atikokan",
            "Atka":"America/Atka",
            "Bahia":"America/Bahia",
            "Bahia_Banderas":"America/Bahia_Banderas",
            "Barbados":"America/Barbados",
            "Belem":"America/Belem",
            "Belize":"America/Belize",
            "Blanc-Sablon":"America/Blanc-Sablon",
            "Boa_Vista":"America/Boa_Vista",
            "Bogota":"America/Bogota",
            "Boise":"America/Boise",
            "Buenos_Aires":"America/Buenos_Aires",
            "Cambridge_Bay":"America/Cambridge_Bay",
            "Campo_Grande":"America/Campo_Grande",
            "Cancun":"America/Cancun",
            "Caracas":"America/Caracas",
            "Catamarca":"America/Catamarca",
            "Cayenne":"America/Cayenne",
            "Cayman":"America/Cayman",
            "Chicago":"America/Chicago",
            "Chihuahua":"America/Chihuahua",
            "Coral_Harbour":"America/Coral_Harbour",
            "Cordoba":"America/Cordoba",
            "Costa_Rica":"America/Costa_Rica",
            "Creston":"America/Creston",
            "Cuiaba":"America/Cuiaba",
            "Curacao":"America/Curacao",
            "Danmarkshavn":"America/Danmarkshavn",
            "Dawson":"America/Dawson",
            "Dawson_Creek":"America/Dawson_Creek",
            "Denver":"America/Denver",
            "Detroit":"America/Detroit",
            "Dominica":"America/Dominica",
            "Edmonton":"America/Edmonton",
            "Eirunepe":"America/Eirunepe",
            "El_Salvador":"America/El_Salvador",
            "Ensenada":"America/Ensenada",
            "Fort_Nelson":"America/Fort_Nelson",
            "Fort_Wayne":"America/Fort_Wayne",
            "Fortaleza":"America/Fortaleza",
            "Glace_Bay":"America/Glace_Bay",
            "Godthab":"America/Godthab",
            "Goose_Bay":"America/Goose_Bay",
            "Grand_Turk":"America/Grand_Turk",
            "Grenada":"America/Grenada",
            "Guadeloupe":"America/Guadeloupe",
            "Guatemala":"America/Guatemala",
            "Guayaquil":"America/Guayaquil",
            "Guyana":"America/Guyana",
            "Halifax":"America/Halifax",
            "Havana":"America/Havana",
            "Hermosillo":"America/Hermosillo",
            "Indianapolis":"America/Indiana/Indianapolis",
            "Knox":"America/Indiana/Knox",
            "Marengo":"America/Indiana/Marengo",
            "Petersburg":"America/Indiana/Petersburg",
            "Tell_City":"America/Indiana/Tell_City",
            "Vevay":"America/Indiana/Vevay",
            "Vincennes":"America/Indiana/Vincennes",
            "Winamac":"America/Indiana/Winamac",
            "Indianapolis":"America/Indianapolis",
            "Inuvik":"America/Inuvik",
            "Iqaluit":"America/Iqaluit",
            "Jamaica":"America/Jamaica",
            "Jujuy":"America/Jujuy",
            "Juneau":"America/Juneau",
            "Louisville":"America/Kentucky/Louisville",
            "Monticello":"America/Kentucky/Monticello",
            "Knox_IN":"America/Knox_IN",
            "Kralendijk":"America/Kralendijk",
            "La_Paz":"America/La_Paz",
            "Lima":"America/Lima",
            "Los_Angeles":"America/Los_Angeles",
            "Louisville":"America/Louisville",
            "Lower_Princes":"America/Lower_Princes",
            "Maceio":"America/Maceio",
            "Managua":"America/Managua",
            "Manaus":"America/Manaus",
            "Marigot":"America/Marigot",
            "Martinique":"America/Martinique",
            "Matamoros":"America/Matamoros",
            "Mazatlan":"America/Mazatlan",
            "Mendoza":"America/Mendoza",
            "Menominee":"America/Menominee",
            "Merida":"America/Merida",
            "Metlakatla":"America/Metlakatla",
            "Mexico_City":"America/Mexico_City",
            "Miquelon":"America/Miquelon",
            "Moncton":"America/Moncton",
            "Monterrey":"America/Monterrey",
            "Montevideo":"America/Montevideo",
            "Montreal":"America/Montreal",
            "Montserrat":"America/Montserrat",
            "Nassau":"America/Nassau",
            "New_York":"America/New_York",
            "Nipigon":"America/Nipigon",
            "Nome":"America/Nome",
            "Noronha":"America/Noronha",
            "Beulah":"America/North_Dakota/Beulah",
            "Center":"America/North_Dakota/Center",
            "New_Salem":"America/North_Dakota/New_Salem",
            "Ojinaga":"America/Ojinaga",
            "Panama":"America/Panama",
            "Pangnirtung":"America/Pangnirtung",
            "Paramaribo":"America/Paramaribo",
            "Phoenix":"America/Phoenix",
            "Port-au-Prince":"America/Port-au-Prince",
            "Port_of_Spain":"America/Port_of_Spain",
            "Porto_Acre":"America/Porto_Acre",
            "Porto_Velho":"America/Porto_Velho",
            "Puerto_Rico":"America/Puerto_Rico",
            "Rainy_River":"America/Rainy_River",
            "Rankin_Inlet":"America/Rankin_Inlet",
            "Recife":"America/Recife",
            "Regina":"America/Regina",
            "Resolute":"America/Resolute",
            "Rio_Branco":"America/Rio_Branco",
            "Rosario":"America/Rosario",
            "Santa_Isabel":"America/Santa_Isabel",
            "Santarem":"America/Santarem",
            "Santiago":"America/Santiago",
            "Santo_Domingo":"America/Santo_Domingo",
            "Sao_Paulo":"America/Sao_Paulo",
            "Scoresbysund":"America/Scoresbysund",
            "Shiprock":"America/Shiprock",
            "Sitka":"America/Sitka",
            "St_Barthelemy":"America/St_Barthelemy",
            "St_Johns":"America/St_Johns",
            "St_Kitts":"America/St_Kitts",
            "St_Lucia":"America/St_Lucia",
            "St_Thomas":"America/St_Thomas",
            "St_Vincent":"America/St_Vincent",
            "Swift_Current":"America/Swift_Current",
            "Tegucigalpa":"America/Tegucigalpa",
            "Thule":"America/Thule",
            "Thunder_Bay":"America/Thunder_Bay",
            "Tijuana":"America/Tijuana",
            "Toronto":"America/Toronto",
            "Tortola":"America/Tortola",
            "Vancouver":"America/Vancouver",
            "Virgin":"America/Virgin",
            "Whitehorse":"America/Whitehorse",
            "Winnipeg":"America/Winnipeg",
            "Yakutat":"America/Yakutat",
            "Yellowknife":"America/Yellowknife",
            "Casey":"Antarctica/Casey",
            "Davis":"Antarctica/Davis",
            "DumontDUrville":"Antarctica/DumontDUrville",
            "Macquarie":"Antarctica/Macquarie",
            "Mawson":"Antarctica/Mawson",
            "McMurdo":"Antarctica/McMurdo",
            "Palmer":"Antarctica/Palmer",
            "Rothera":"Antarctica/Rothera",
            "South_Pole":"Antarctica/South_Pole",
            "Syowa":"Antarctica/Syowa",
            "Troll":"Antarctica/Troll",
            "Vostok":"Antarctica/Vostok",
            "Longyearbyen":"Arctic/Longyearbyen",
            "Aden":"Asia/Aden",
            "Almaty":"Asia/Almaty",
            "Amman":"Asia/Amman",
            "Anadyr":"Asia/Anadyr",
            "Aqtau":"Asia/Aqtau",
            "Aqtobe":"Asia/Aqtobe",
            "Ashgabat":"Asia/Ashgabat",
            "Ashkhabad":"Asia/Ashkhabad",
            "Atyrau":"Asia/Atyrau",
            "Baghdad":"Asia/Baghdad",
            "Bahrain":"Asia/Bahrain",
            "Baku":"Asia/Baku",
            "Bangkok":"Asia/Bangkok",
            "Barnaul":"Asia/Barnaul",
            "Beirut":"Asia/Beirut",
            "Bishkek":"Asia/Bishkek",
            "Brunei":"Asia/Brunei",
            "Calcutta":"Asia/Calcutta",
            "Chita":"Asia/Chita",
            "Choibalsan":"Asia/Choibalsan",
            "Chongqing":"Asia/Chongqing",
            "Chungking":"Asia/Chungking",
            "Colombo":"Asia/Colombo",
            "Dacca":"Asia/Dacca",
            "Damascus":"Asia/Damascus",
            "Dhaka":"Asia/Dhaka",
            "Dili":"Asia/Dili",
            "Dubai":"Asia/Dubai",
            "Dushanbe":"Asia/Dushanbe",
            "Famagusta":"Asia/Famagusta",
            "Gaza":"Asia/Gaza",
            "Harbin":"Asia/Harbin",
            "Hebron":"Asia/Hebron",
            "Ho_Chi_Minh":"Asia/Ho_Chi_Minh",
            "Hong_Kong":"Asia/Hong_Kong",
            "Hovd":"Asia/Hovd",
            "Irkutsk":"Asia/Irkutsk",
            "Istanbul":"Asia/Istanbul",
            "Jakarta":"Asia/Jakarta",
            "Jayapura":"Asia/Jayapura",
            "Jerusalem":"Asia/Jerusalem",
            "Kabul":"Asia/Kabul",
            "Kamchatka":"Asia/Kamchatka",
            "Karachi":"Asia/Karachi",
            "Kashgar":"Asia/Kashgar",
            "Kathmandu":"Asia/Kathmandu",
            "Katmandu":"Asia/Katmandu",
            "Khandyga":"Asia/Khandyga",
            "Kolkata":"Asia/Kolkata",
            "Krasnoyarsk":"Asia/Krasnoyarsk",
            "Kuala_Lumpur":"Asia/Kuala_Lumpur",
            "Kuching":"Asia/Kuching",
            "Kuwait":"Asia/Kuwait",
            "Macao":"Asia/Macao",
            "Macau":"Asia/Macau",
            "Magadan":"Asia/Magadan",
            "Makassar":"Asia/Makassar",
            "Manila":"Asia/Manila",
            "Muscat":"Asia/Muscat",
            "Nicosia":"Asia/Nicosia",
            "Novokuznetsk":"Asia/Novokuznetsk",
            "Novosibirsk":"Asia/Novosibirsk",
            "Omsk":"Asia/Omsk",
            "Oral":"Asia/Oral",
            "Phnom_Penh":"Asia/Phnom_Penh",
            "Pontianak":"Asia/Pontianak",
            "Pyongyang":"Asia/Pyongyang",
            "Qatar":"Asia/Qatar",
            "Qyzylorda":"Asia/Qyzylorda",
            "Rangoon":"Asia/Rangoon",
            "Riyadh":"Asia/Riyadh",
            "Saigon":"Asia/Saigon",
            "Sakhalin":"Asia/Sakhalin",
            "Samarkand":"Asia/Samarkand",
            "Seoul":"Asia/Seoul",
            "Shanghai":"Asia/Shanghai",
            "Singapore":"Asia/Singapore",
            "Srednekolymsk":"Asia/Srednekolymsk",
            "Taipei":"Asia/Taipei",
            "Tashkent":"Asia/Tashkent",
            "Tbilisi":"Asia/Tbilisi",
            "Tehran":"Asia/Tehran",
            "Tel_Aviv":"Asia/Tel_Aviv",
            "Thimbu":"Asia/Thimbu",
            "Thimphu":"Asia/Thimphu",
            "Tokyo":"Asia/Tokyo",
            "Tomsk":"Asia/Tomsk",
            "Ujung_Pandang":"Asia/Ujung_Pandang",
            "Ulaanbaatar":"Asia/Ulaanbaatar",
            "Ulan_Bator":"Asia/Ulan_Bator",
            "Urumqi":"Asia/Urumqi",
            "Ust-Nera":"Asia/Ust-Nera",
            "Vientiane":"Asia/Vientiane",
            "Vladivostok":"Asia/Vladivostok",
            "Yakutsk":"Asia/Yakutsk",
            "Yangon":"Asia/Yangon",
            "Yekaterinburg":"Asia/Yekaterinburg",
            "Yerevan":"Asia/Yerevan",
            "Azores":"Atlantic/Azores",
            "Bermuda":"Atlantic/Bermuda",
            "Canary":"Atlantic/Canary",
            "Cape_Verde":"Atlantic/Cape_Verde",
            "Faeroe":"Atlantic/Faeroe",
            "Faroe":"Atlantic/Faroe",
            "Jan_Mayen":"Atlantic/Jan_Mayen",
            "Madeira":"Atlantic/Madeira",
            "Reykjavik":"Atlantic/Reykjavik",
            "South_Georgia":"Atlantic/South_Georgia",
            "St_Helena":"Atlantic/St_Helena",
            "Stanley":"Atlantic/Stanley",
            "ACT":"Australia/ACT",
            "Adelaide":"Australia/Adelaide",
            "Brisbane":"Australia/Brisbane",
            "Broken_Hill":"Australia/Broken_Hill",
            "Canberra":"Australia/Canberra",
            "Currie":"Australia/Currie",
            "Darwin":"Australia/Darwin",
            "Eucla":"Australia/Eucla",
            "Hobart":"Australia/Hobart",
            "LHI":"Australia/LHI",
            "Lindeman":"Australia/Lindeman",
            "Lord_Howe":"Australia/Lord_Howe",
            "Melbourne":"Australia/Melbourne",
            "NSW":"Australia/NSW",
            "North":"Australia/North",
            "Perth":"Australia/Perth",
            "Queensland":"Australia/Queensland",
            "South":"Australia/South",
            "Sydney":"Australia/Sydney",
            "Tasmania":"Australia/Tasmania",
            "Victoria":"Australia/Victoria",
            "West":"Australia/West",
            "Yancowinna":"Australia/Yancowinna",
            "Acre":"Brazil/Acre",
            "DeNoronha":"Brazil/DeNoronha",
            "East":"Brazil/East",
            "West":"Brazil/West",
            "Atlantic":"Canada/Atlantic",
            "Central":"Canada/Central",
            "East-Saskatchewan":"Canada/East-Saskatchewan",
            "Eastern":"Canada/Eastern",
            "Mountain":"Canada/Mountain",
            "Newfoundland":"Canada/Newfoundland",
            "Pacific":"Canada/Pacific",
            "Saskatchewan":"Canada/Saskatchewan",
            "Yukon":"Canada/Yukon",
            "Continental":"Chile/Continental",
            "EasterIsland":"Chile/EasterIsland",
            "GMT":"Etc/GMT",
            "GMT+0":"Etc/GMT+0",
            "GMT+1":"Etc/GMT+1",
            "GMT+10":"Etc/GMT+10",
            "GMT+11":"Etc/GMT+11",
            "GMT+12":"Etc/GMT+12",
            "GMT+2":"Etc/GMT+2",
            "GMT+3":"Etc/GMT+3",
            "GMT+4":"Etc/GMT+4",
            "GMT+5":"Etc/GMT+5",
            "GMT+6":"Etc/GMT+6",
            "GMT+7":"Etc/GMT+7",
            "GMT+8":"Etc/GMT+8",
            "GMT+9":"Etc/GMT+9",
            "GMT-0":"Etc/GMT-0",
            "GMT-1":"Etc/GMT-1",
            "GMT-10":"Etc/GMT-10",
            "GMT-11":"Etc/GMT-11",
            "GMT-12":"Etc/GMT-12",
            "GMT-13":"Etc/GMT-13",
            "GMT-14":"Etc/GMT-14",
            "GMT-2":"Etc/GMT-2",
            "GMT-3":"Etc/GMT-3",
            "GMT-4":"Etc/GMT-4",
            "GMT-5":"Etc/GMT-5",
            "GMT-6":"Etc/GMT-6",
            "GMT-7":"Etc/GMT-7",
            "GMT-8":"Etc/GMT-8",
            "GMT-9":"Etc/GMT-9",
            "GMT0":"Etc/GMT0",
            "Greenwich":"Etc/Greenwich",
            "UCT":"Etc/UCT",
            "UTC":"Etc/UTC",
            "Universal":"Etc/Universal",
            "Zulu":"Etc/Zulu",
            "Amsterdam":"Europe/Amsterdam",
            "Andorra":"Europe/Andorra",
            "Astrakhan":"Europe/Astrakhan",
            "Athens":"Europe/Athens",
            "Belfast":"Europe/Belfast",
            "Belgrade":"Europe/Belgrade",
            "Berlin":"Europe/Berlin",
            "Bratislava":"Europe/Bratislava",
            "Brussels":"Europe/Brussels",
            "Bucharest":"Europe/Bucharest",
            "Budapest":"Europe/Budapest",
            "Busingen":"Europe/Busingen",
            "Chisinau":"Europe/Chisinau",
            "Copenhagen":"Europe/Copenhagen",
            "Dublin":"Europe/Dublin",
            "Gibraltar":"Europe/Gibraltar",
            "Guernsey":"Europe/Guernsey",
            "Helsinki":"Europe/Helsinki",
            "Isle_of_Man":"Europe/Isle_of_Man",
            "Istanbul":"Europe/Istanbul",
            "Jersey":"Europe/Jersey",
            "Kaliningrad":"Europe/Kaliningrad",
            "Kiev":"Europe/Kiev",
            "Kirov":"Europe/Kirov",
            "Lisbon":"Europe/Lisbon",
            "Ljubljana":"Europe/Ljubljana",
            "London":"Europe/London",
            "Luxembourg":"Europe/Luxembourg",
            "Madrid":"Europe/Madrid",
            "Malta":"Europe/Malta",
            "Mariehamn":"Europe/Mariehamn",
            "Minsk":"Europe/Minsk",
            "Monaco":"Europe/Monaco",
            "Moscow":"Europe/Moscow",
            "Nicosia":"Europe/Nicosia",
            "Oslo":"Europe/Oslo",
            "Paris":"Europe/Paris",
            "Podgorica":"Europe/Podgorica",
            "Prague":"Europe/Prague",
            "Riga":"Europe/Riga",
            "Rome":"Europe/Rome",
            "Samara":"Europe/Samara",
            "San_Marino":"Europe/San_Marino",
            "Sarajevo":"Europe/Sarajevo",
            "Saratov":"Europe/Saratov",
            "Simferopol":"Europe/Simferopol",
            "Skopje":"Europe/Skopje",
            "Sofia":"Europe/Sofia",
            "Stockholm":"Europe/Stockholm",
            "Tallinn":"Europe/Tallinn",
            "Tirane":"Europe/Tirane",
            "Tiraspol":"Europe/Tiraspol",
            "Ulyanovsk":"Europe/Ulyanovsk",
            "Uzhgorod":"Europe/Uzhgorod",
            "Vaduz":"Europe/Vaduz",
            "Vatican":"Europe/Vatican",
            "Vienna":"Europe/Vienna",
            "Vilnius":"Europe/Vilnius",
            "Volgograd":"Europe/Volgograd",
            "Warsaw":"Europe/Warsaw",
            "Zagreb":"Europe/Zagreb",
            "Zaporozhye":"Europe/Zaporozhye",
            "Zurich":"Europe/Zurich",
            "Antananarivo":"Indian/Antananarivo",
            "Chagos":"Indian/Chagos",
            "Christmas":"Indian/Christmas",
            "Cocos":"Indian/Cocos",
            "Comoro":"Indian/Comoro",
            "Kerguelen":"Indian/Kerguelen",
            "Mahe":"Indian/Mahe",
            "Maldives":"Indian/Maldives",
            "Mauritius":"Indian/Mauritius",
            "Mayotte":"Indian/Mayotte",
            "Reunion":"Indian/Reunion",
            "BajaNorte":"Mexico/BajaNorte",
            "BajaSur":"Mexico/BajaSur",
            "General":"Mexico/General",
            "localtime":"Msft/localtime",
            "Apia":"Pacific/Apia",
            "Auckland":"Pacific/Auckland",
            "Bougainville":"Pacific/Bougainville",
            "Chatham":"Pacific/Chatham",
            "Chuuk":"Pacific/Chuuk",
            "Easter":"Pacific/Easter",
            "Efate":"Pacific/Efate",
            "Enderbury":"Pacific/Enderbury",
            "Fakaofo":"Pacific/Fakaofo",
            "Fiji":"Pacific/Fiji",
            "Funafuti":"Pacific/Funafuti",
            "Galapagos":"Pacific/Galapagos",
            "Gambier":"Pacific/Gambier",
            "Guadalcanal":"Pacific/Guadalcanal",
            "Guam":"Pacific/Guam",
            "Honolulu":"Pacific/Honolulu",
            "Johnston":"Pacific/Johnston",
            "Kiritimati":"Pacific/Kiritimati",
            "Kosrae":"Pacific/Kosrae",
            "Kwajalein":"Pacific/Kwajalein",
            "Majuro":"Pacific/Majuro",
            "Marquesas":"Pacific/Marquesas",
            "Midway":"Pacific/Midway",
            "Nauru":"Pacific/Nauru",
            "Niue":"Pacific/Niue",
            "Norfolk":"Pacific/Norfolk",
            "Noumea":"Pacific/Noumea",
            "Pago_Pago":"Pacific/Pago_Pago",
            "Palau":"Pacific/Palau",
            "Pitcairn":"Pacific/Pitcairn",
            "Pohnpei":"Pacific/Pohnpei",
            "Ponape":"Pacific/Ponape",
            "Port_Moresby":"Pacific/Port_Moresby",
            "Rarotonga":"Pacific/Rarotonga",
            "Saipan":"Pacific/Saipan",
            "Samoa":"Pacific/Samoa",
            "Tahiti":"Pacific/Tahiti",
            "Tarawa":"Pacific/Tarawa",
            "Tongatapu":"Pacific/Tongatapu",
            "Truk":"Pacific/Truk",
            "Wake":"Pacific/Wake",
            "Wallis":"Pacific/Wallis",
            "Yap":"Pacific/Yap",
            "Alaska":"US/Alaska",
            "Aleutian":"US/Aleutian",
            "Arizona":"US/Arizona",
            "Central":"US/Central",
            "East-Indiana":"US/East-Indiana",
            "Eastern":"US/Eastern",
            "Hawaii":"US/Hawaii",
            "Indiana-Starke":"US/Indiana-Starke",
            "Michigan":"US/Michigan",
            "Mountain":"US/Mountain",
            "Pacific":"US/Pacific",
            "Pacific-New":"US/Pacific-New",
            "Samoa":"US/Samoa"
        ];
        shortNames = cast(immutable) tzNames;
        import std.stdio;
        try
        {
            if (PosixTimeZone.getInstalledTZNames().length == 0)
            {
                writeln("Warning, no timezone data detected! Falling back to UTC.");
                hasTzData = false;
            }
            else
                hasTzData = true;
        }
        catch(Exception e)
        {
            writeln("Warning, no timezone data detected! Falling back to UTC. Details: ", e);
        }
    }
    
    static immutable bool hasTzData; 

    static immutable(TimeZone) timeZone(string name)
    {
        if (!hasTzData || name.toUpper == "UTC")
            return UTC();
        try
        {
            return PosixTimeZone.getTimeZone(name);
        }
        catch(Exception e)
        {
           name = shortNames[name];
           return PosixTimeZone.getTimeZone(name);
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
    
    static immutable(TimeZone) timeZone(string name)
    {
        if (name.toUpper == "UTC")
            return UTC();
        if (name in conv.toWindows)
        {
            auto list = conv.toWindows[name];
            return WindowsTimeZone.getTimeZone(list[0]);
        }
        else
        {
            return shortNames[name];
        }
    }

    static string getTimeZoneName(immutable(TimeZone) tz)
    {
        if (tz.stdName == "Coordinated Universal Time")
            return "UTC";
        if (tz.stdName in conv.fromWindows)
        {
            auto list = conv.fromWindows[tz.stdName];
            if (list.length > 0)
                return cityName(list[0]);
        }
        return "";
    }

    
    immutable static __gshared TZConversions conv;
    immutable static __gshared TimeZone[string] shortNames;
    
    shared static this()
    {
        conv = parseTZConversions(windowsZones);

        foreach(ref shortNameList; conv.fromWindows.byValue)
        {
            foreach(ref fullName; shortNameList)
            {
                auto shortName = cityName(fullName);
                auto tzName = conv.toWindows[fullName][0];
                shortNames[shortName] = WindowsTimeZone.getTimeZone(tzName);
            }
        }

    }

    private static immutable __gshared windowsZones = `<supplementalData>
        <version number="$Revision$"/>
        <windowsZones>
        <mapTimezones otherVersion="7e00402" typeVersion="2016j">
        <!--  (UTC-12:00) International Date Line West  -->
        <mapZone other="Dateline Standard Time" territory="001" type="Etc/GMT+12"/>
        <mapZone other="Dateline Standard Time" territory="ZZ" type="Etc/GMT+12"/>
        <!--  (UTC-11:00) Coordinated Universal Time-11  -->
        <mapZone other="UTC-11" territory="001" type="Etc/GMT+11"/>
        <mapZone other="UTC-11" territory="AS" type="Pacific/Pago_Pago"/>
        <mapZone other="UTC-11" territory="NU" type="Pacific/Niue"/>
        <mapZone other="UTC-11" territory="UM" type="Pacific/Midway"/>
        <mapZone other="UTC-11" territory="ZZ" type="Etc/GMT+11"/>
        <!--  (UTC-10:00) Aleutian Islands  -->
        <mapZone other="Aleutian Standard Time" territory="001" type="America/Adak"/>
        <mapZone other="Aleutian Standard Time" territory="US" type="America/Adak"/>
        <!--  (UTC-10:00) Hawaii  -->
        <mapZone other="Hawaiian Standard Time" territory="001" type="Pacific/Honolulu"/>
        <mapZone other="Hawaiian Standard Time" territory="CK" type="Pacific/Rarotonga"/>
        <mapZone other="Hawaiian Standard Time" territory="PF" type="Pacific/Tahiti"/>
        <mapZone other="Hawaiian Standard Time" territory="UM" type="Pacific/Johnston"/>
        <mapZone other="Hawaiian Standard Time" territory="US" type="Pacific/Honolulu"/>
        <mapZone other="Hawaiian Standard Time" territory="ZZ" type="Etc/GMT+10"/>
        <!--  (UTC-09:30) Marquesas Islands  -->
        <mapZone other="Marquesas Standard Time" territory="001" type="Pacific/Marquesas"/>
        <mapZone other="Marquesas Standard Time" territory="PF" type="Pacific/Marquesas"/>
        <!--  (UTC-09:00) Alaska  -->
        <mapZone other="Alaskan Standard Time" territory="001" type="America/Anchorage"/>
        <mapZone other="Alaskan Standard Time" territory="US" type="America/Anchorage America/Juneau America/Metlakatla America/Nome America/Sitka America/Yakutat"/>
        <!--  (UTC-09:00) Coordinated Universal Time-09  -->
        <mapZone other="UTC-09" territory="001" type="Etc/GMT+9"/>
        <mapZone other="UTC-09" territory="PF" type="Pacific/Gambier"/>
        <mapZone other="UTC-09" territory="ZZ" type="Etc/GMT+9"/>
        <!--  (UTC-08:00) Baja California  -->
        <mapZone other="Pacific Standard Time (Mexico)" territory="001" type="America/Tijuana"/>
        <mapZone other="Pacific Standard Time (Mexico)" territory="MX" type="America/Tijuana America/Santa_Isabel"/>
        <!--  (UTC-08:00) Coordinated Universal Time-08  -->
        <mapZone other="UTC-08" territory="001" type="Etc/GMT+8"/>
        <mapZone other="UTC-08" territory="PN" type="Pacific/Pitcairn"/>
        <mapZone other="UTC-08" territory="ZZ" type="Etc/GMT+8"/>
        <!--  (UTC-08:00) Pacific Time (US & Canada)  -->
        <mapZone other="Pacific Standard Time" territory="001" type="America/Los_Angeles"/>
        <mapZone other="Pacific Standard Time" territory="CA" type="America/Vancouver America/Dawson America/Whitehorse"/>
        <mapZone other="Pacific Standard Time" territory="US" type="America/Los_Angeles"/>
        <mapZone other="Pacific Standard Time" territory="ZZ" type="PST8PDT"/>
        <!--  (UTC-07:00) Arizona  -->
        <mapZone other="US Mountain Standard Time" territory="001" type="America/Phoenix"/>
        <mapZone other="US Mountain Standard Time" territory="CA" type="America/Dawson_Creek America/Creston America/Fort_Nelson"/>
        <mapZone other="US Mountain Standard Time" territory="MX" type="America/Hermosillo"/>
        <mapZone other="US Mountain Standard Time" territory="US" type="America/Phoenix"/>
        <mapZone other="US Mountain Standard Time" territory="ZZ" type="Etc/GMT+7"/>
        <!--  (UTC-07:00) Chihuahua, La Paz, Mazatlan  -->
        <mapZone other="Mountain Standard Time (Mexico)" territory="001" type="America/Chihuahua"/>
        <mapZone other="Mountain Standard Time (Mexico)" territory="MX" type="America/Chihuahua America/Mazatlan"/>
        <!--  (UTC-07:00) Mountain Time (US & Canada)  -->
        <mapZone other="Mountain Standard Time" territory="001" type="America/Denver"/>
        <mapZone other="Mountain Standard Time" territory="CA" type="America/Edmonton America/Cambridge_Bay America/Inuvik America/Yellowknife"/>
        <mapZone other="Mountain Standard Time" territory="MX" type="America/Ojinaga"/>
        <mapZone other="Mountain Standard Time" territory="US" type="America/Denver America/Boise"/>
        <mapZone other="Mountain Standard Time" territory="ZZ" type="MST7MDT"/>
        <!--  (UTC-06:00) Central America  -->
        <mapZone other="Central America Standard Time" territory="001" type="America/Guatemala"/>
        <mapZone other="Central America Standard Time" territory="BZ" type="America/Belize"/>
        <mapZone other="Central America Standard Time" territory="CR" type="America/Costa_Rica"/>
        <mapZone other="Central America Standard Time" territory="EC" type="Pacific/Galapagos"/>
        <mapZone other="Central America Standard Time" territory="GT" type="America/Guatemala"/>
        <mapZone other="Central America Standard Time" territory="HN" type="America/Tegucigalpa"/>
        <mapZone other="Central America Standard Time" territory="NI" type="America/Managua"/>
        <mapZone other="Central America Standard Time" territory="SV" type="America/El_Salvador"/>
        <mapZone other="Central America Standard Time" territory="ZZ" type="Etc/GMT+6"/>
        <!--  (UTC-06:00) Central Time (US & Canada)  -->
        <mapZone other="Central Standard Time" territory="001" type="America/Chicago"/>
        <mapZone other="Central Standard Time" territory="CA" type="America/Winnipeg America/Rainy_River America/Rankin_Inlet America/Resolute"/>
        <mapZone other="Central Standard Time" territory="MX" type="America/Matamoros"/>
        <mapZone other="Central Standard Time" territory="US" type="America/Chicago America/Indiana/Knox America/Indiana/Tell_City America/Menominee America/North_Dakota/Beulah America/North_Dakota/Center America/North_Dakota/New_Salem"/>
        <mapZone other="Central Standard Time" territory="ZZ" type="CST6CDT"/>
        <!--  (UTC-06:00) Easter Island  -->
        <mapZone other="Easter Island Standard Time" territory="001" type="Pacific/Easter"/>
        <mapZone other="Easter Island Standard Time" territory="CL" type="Pacific/Easter"/>
        <!--  (UTC-06:00) Guadalajara, Mexico City, Monterrey  -->
        <mapZone other="Central Standard Time (Mexico)" territory="001" type="America/Mexico_City"/>
        <mapZone other="Central Standard Time (Mexico)" territory="MX" type="America/Mexico_City America/Bahia_Banderas America/Merida America/Monterrey"/>
        <!--  (UTC-06:00) Saskatchewan  -->
        <mapZone other="Canada Central Standard Time" territory="001" type="America/Regina"/>
        <mapZone other="Canada Central Standard Time" territory="CA" type="America/Regina America/Swift_Current"/>
        <!--  (UTC-05:00) Bogota, Lima, Quito, Rio Branco  -->
        <mapZone other="SA Pacific Standard Time" territory="001" type="America/Bogota"/>
        <mapZone other="SA Pacific Standard Time" territory="BR" type="America/Rio_Branco America/Eirunepe"/>
        <mapZone other="SA Pacific Standard Time" territory="CA" type="America/Coral_Harbour"/>
        <mapZone other="SA Pacific Standard Time" territory="CO" type="America/Bogota"/>
        <mapZone other="SA Pacific Standard Time" territory="EC" type="America/Guayaquil"/>
        <mapZone other="SA Pacific Standard Time" territory="JM" type="America/Jamaica"/>
        <mapZone other="SA Pacific Standard Time" territory="KY" type="America/Cayman"/>
        <mapZone other="SA Pacific Standard Time" territory="PA" type="America/Panama"/>
        <mapZone other="SA Pacific Standard Time" territory="PE" type="America/Lima"/>
        <mapZone other="SA Pacific Standard Time" territory="ZZ" type="Etc/GMT+5"/>
        <!--  (UTC-05:00) Chetumal  -->
        <mapZone other="Eastern Standard Time (Mexico)" territory="001" type="America/Cancun"/>
        <mapZone other="Eastern Standard Time (Mexico)" territory="MX" type="America/Cancun"/>
        <!--  (UTC-05:00) Eastern Time (US & Canada)  -->
        <mapZone other="Eastern Standard Time" territory="001" type="America/New_York"/>
        <mapZone other="Eastern Standard Time" territory="BS" type="America/Nassau"/>
        <mapZone other="Eastern Standard Time" territory="CA" type="America/Toronto America/Iqaluit America/Montreal America/Nipigon America/Pangnirtung America/Thunder_Bay"/>
        <mapZone other="Eastern Standard Time" territory="US" type="America/New_York America/Detroit America/Indiana/Petersburg America/Indiana/Vincennes America/Indiana/Winamac America/Kentucky/Monticello America/Louisville"/>
        <mapZone other="Eastern Standard Time" territory="ZZ" type="EST5EDT"/>
        <!--  (UTC-05:00) Haiti  -->
        <mapZone other="Haiti Standard Time" territory="001" type="America/Port-au-Prince"/>
        <mapZone other="Haiti Standard Time" territory="HT" type="America/Port-au-Prince"/>
        <!--  (UTC-05:00) Havana  -->
        <mapZone other="Cuba Standard Time" territory="001" type="America/Havana"/>
        <mapZone other="Cuba Standard Time" territory="CU" type="America/Havana"/>
        <!--  (UTC-05:00) Indiana (East)  -->
        <mapZone other="US Eastern Standard Time" territory="001" type="America/Indianapolis"/>
        <mapZone other="US Eastern Standard Time" territory="US" type="America/Indianapolis America/Indiana/Marengo America/Indiana/Vevay"/>
        <!--  (UTC-04:00) Asuncion  -->
        <mapZone other="Paraguay Standard Time" territory="001" type="America/Asuncion"/>
        <mapZone other="Paraguay Standard Time" territory="PY" type="America/Asuncion"/>
        <!--  (UTC-04:00) Atlantic Time (Canada)  -->
        <mapZone other="Atlantic Standard Time" territory="001" type="America/Halifax"/>
        <mapZone other="Atlantic Standard Time" territory="BM" type="Atlantic/Bermuda"/>
        <mapZone other="Atlantic Standard Time" territory="CA" type="America/Halifax America/Glace_Bay America/Goose_Bay America/Moncton"/>
        <mapZone other="Atlantic Standard Time" territory="GL" type="America/Thule"/>
        <!--  (UTC-04:00) Caracas  -->
        <mapZone other="Venezuela Standard Time" territory="001" type="America/Caracas"/>
        <mapZone other="Venezuela Standard Time" territory="VE" type="America/Caracas"/>
        <!--  (UTC-04:00) Cuiaba  -->
        <mapZone other="Central Brazilian Standard Time" territory="001" type="America/Cuiaba"/>
        <mapZone other="Central Brazilian Standard Time" territory="BR" type="America/Cuiaba America/Campo_Grande"/>
        <!--  (UTC-04:00) Georgetown, La Paz, Manaus, San Juan  -->
        <mapZone other="SA Western Standard Time" territory="001" type="America/La_Paz"/>
        <mapZone other="SA Western Standard Time" territory="AG" type="America/Antigua"/>
        <mapZone other="SA Western Standard Time" territory="AI" type="America/Anguilla"/>
        <mapZone other="SA Western Standard Time" territory="AW" type="America/Aruba"/>
        <mapZone other="SA Western Standard Time" territory="BB" type="America/Barbados"/>
        <mapZone other="SA Western Standard Time" territory="BL" type="America/St_Barthelemy"/>
        <mapZone other="SA Western Standard Time" territory="BO" type="America/La_Paz"/>
        <mapZone other="SA Western Standard Time" territory="BQ" type="America/Kralendijk"/>
        <mapZone other="SA Western Standard Time" territory="BR" type="America/Manaus America/Boa_Vista America/Porto_Velho"/>
        <mapZone other="SA Western Standard Time" territory="CA" type="America/Blanc-Sablon"/>
        <mapZone other="SA Western Standard Time" territory="CW" type="America/Curacao"/>
        <mapZone other="SA Western Standard Time" territory="DM" type="America/Dominica"/>
        <mapZone other="SA Western Standard Time" territory="DO" type="America/Santo_Domingo"/>
        <mapZone other="SA Western Standard Time" territory="GD" type="America/Grenada"/>
        <mapZone other="SA Western Standard Time" territory="GP" type="America/Guadeloupe"/>
        <mapZone other="SA Western Standard Time" territory="GY" type="America/Guyana"/>
        <mapZone other="SA Western Standard Time" territory="KN" type="America/St_Kitts"/>
        <mapZone other="SA Western Standard Time" territory="LC" type="America/St_Lucia"/>
        <mapZone other="SA Western Standard Time" territory="MF" type="America/Marigot"/>
        <mapZone other="SA Western Standard Time" territory="MQ" type="America/Martinique"/>
        <mapZone other="SA Western Standard Time" territory="MS" type="America/Montserrat"/>
        <mapZone other="SA Western Standard Time" territory="PR" type="America/Puerto_Rico"/>
        <mapZone other="SA Western Standard Time" territory="SX" type="America/Lower_Princes"/>
        <mapZone other="SA Western Standard Time" territory="TT" type="America/Port_of_Spain"/>
        <mapZone other="SA Western Standard Time" territory="VC" type="America/St_Vincent"/>
        <mapZone other="SA Western Standard Time" territory="VG" type="America/Tortola"/>
        <mapZone other="SA Western Standard Time" territory="VI" type="America/St_Thomas"/>
        <mapZone other="SA Western Standard Time" territory="ZZ" type="Etc/GMT+4"/>
        <!--  (UTC-04:00) Santiago  -->
        <mapZone other="Pacific SA Standard Time" territory="001" type="America/Santiago"/>
        <mapZone other="Pacific SA Standard Time" territory="AQ" type="Antarctica/Palmer"/>
        <mapZone other="Pacific SA Standard Time" territory="CL" type="America/Santiago"/>
        <!--  (UTC-04:00) Turks and Caicos  -->
        <mapZone other="Turks And Caicos Standard Time" territory="001" type="America/Grand_Turk"/>
        <mapZone other="Turks And Caicos Standard Time" territory="TC" type="America/Grand_Turk"/>
        <!--  (UTC-03:30) Newfoundland  -->
        <mapZone other="Newfoundland Standard Time" territory="001" type="America/St_Johns"/>
        <mapZone other="Newfoundland Standard Time" territory="CA" type="America/St_Johns"/>
        <!--  (UTC-03:00) Araguaina  -->
        <mapZone other="Tocantins Standard Time" territory="001" type="America/Araguaina"/>
        <mapZone other="Tocantins Standard Time" territory="BR" type="America/Araguaina"/>
        <!--  (UTC-03:00) Brasilia  -->
        <mapZone other="E. South America Standard Time" territory="001" type="America/Sao_Paulo"/>
        <mapZone other="E. South America Standard Time" territory="BR" type="America/Sao_Paulo"/>
        <!--  (UTC-03:00) Cayenne, Fortaleza  -->
        <mapZone other="SA Eastern Standard Time" territory="001" type="America/Cayenne"/>
        <mapZone other="SA Eastern Standard Time" territory="AQ" type="Antarctica/Rothera"/>
        <mapZone other="SA Eastern Standard Time" territory="BR" type="America/Fortaleza America/Belem America/Maceio America/Recife America/Santarem"/>
        <mapZone other="SA Eastern Standard Time" territory="FK" type="Atlantic/Stanley"/>
        <mapZone other="SA Eastern Standard Time" territory="GF" type="America/Cayenne"/>
        <mapZone other="SA Eastern Standard Time" territory="SR" type="America/Paramaribo"/>
        <mapZone other="SA Eastern Standard Time" territory="ZZ" type="Etc/GMT+3"/>
        <!--  (UTC-03:00) City of Buenos Aires  -->
        <mapZone other="Argentina Standard Time" territory="001" type="America/Buenos_Aires"/>
        <mapZone other="Argentina Standard Time" territory="AR" type="America/Buenos_Aires America/Argentina/La_Rioja America/Argentina/Rio_Gallegos America/Argentina/Salta America/Argentina/San_Juan America/Argentina/San_Luis America/Argentina/Tucuman America/Argentina/Ushuaia America/Catamarca America/Cordoba America/Jujuy America/Mendoza"/>
        <!--  (UTC-03:00) Greenland  -->
        <mapZone other="Greenland Standard Time" territory="001" type="America/Godthab"/>
        <mapZone other="Greenland Standard Time" territory="GL" type="America/Godthab"/>
        <!--  (UTC-03:00) Montevideo  -->
        <mapZone other="Montevideo Standard Time" territory="001" type="America/Montevideo"/>
        <mapZone other="Montevideo Standard Time" territory="UY" type="America/Montevideo"/>
        <!--  (UTC-03:00) Saint Pierre and Miquelon  -->
        <mapZone other="Saint Pierre Standard Time" territory="001" type="America/Miquelon"/>
        <mapZone other="Saint Pierre Standard Time" territory="PM" type="America/Miquelon"/>
        <!--  (UTC-03:00) Salvador  -->
        <mapZone other="Bahia Standard Time" territory="001" type="America/Bahia"/>
        <mapZone other="Bahia Standard Time" territory="BR" type="America/Bahia"/>
        <!--  (UTC-02:00) Coordinated Universal Time-02  -->
        <mapZone other="UTC-02" territory="001" type="Etc/GMT+2"/>
        <mapZone other="UTC-02" territory="BR" type="America/Noronha"/>
        <mapZone other="UTC-02" territory="GS" type="Atlantic/South_Georgia"/>
        <mapZone other="UTC-02" territory="ZZ" type="Etc/GMT+2"/>
        <!--  (UTC-01:00) Azores  -->
        <mapZone other="Azores Standard Time" territory="001" type="Atlantic/Azores"/>
        <mapZone other="Azores Standard Time" territory="GL" type="America/Scoresbysund"/>
        <mapZone other="Azores Standard Time" territory="PT" type="Atlantic/Azores"/>
        <!--  (UTC-01:00) Cabo Verde Is.  -->
        <mapZone other="Cape Verde Standard Time" territory="001" type="Atlantic/Cape_Verde"/>
        <mapZone other="Cape Verde Standard Time" territory="CV" type="Atlantic/Cape_Verde"/>
        <mapZone other="Cape Verde Standard Time" territory="ZZ" type="Etc/GMT+1"/>
        <!--  (UTC) Coordinated Universal Time  -->
        <mapZone other="UTC" territory="001" type="Etc/GMT"/>
        <mapZone other="UTC" territory="GL" type="America/Danmarkshavn"/>
        <mapZone other="UTC" territory="ZZ" type="Etc/GMT"/>
        <!--  (UTC+00:00) Casablanca  -->
        <mapZone other="Morocco Standard Time" territory="001" type="Africa/Casablanca"/>
        <mapZone other="Morocco Standard Time" territory="EH" type="Africa/El_Aaiun"/>
        <mapZone other="Morocco Standard Time" territory="MA" type="Africa/Casablanca"/>
        <!--  (UTC+00:00) Dublin, Edinburgh, Lisbon, London  -->
        <mapZone other="GMT Standard Time" territory="001" type="Europe/London"/>
        <mapZone other="GMT Standard Time" territory="ES" type="Atlantic/Canary"/>
        <mapZone other="GMT Standard Time" territory="FO" type="Atlantic/Faeroe"/>
        <mapZone other="GMT Standard Time" territory="GB" type="Europe/London"/>
        <mapZone other="GMT Standard Time" territory="GG" type="Europe/Guernsey"/>
        <mapZone other="GMT Standard Time" territory="IE" type="Europe/Dublin"/>
        <mapZone other="GMT Standard Time" territory="IM" type="Europe/Isle_of_Man"/>
        <mapZone other="GMT Standard Time" territory="JE" type="Europe/Jersey"/>
        <mapZone other="GMT Standard Time" territory="PT" type="Europe/Lisbon Atlantic/Madeira"/>
        <!--  (UTC+00:00) Monrovia, Reykjavik  -->
        <mapZone other="Greenwich Standard Time" territory="001" type="Atlantic/Reykjavik"/>
        <mapZone other="Greenwich Standard Time" territory="BF" type="Africa/Ouagadougou"/>
        <mapZone other="Greenwich Standard Time" territory="CI" type="Africa/Abidjan"/>
        <mapZone other="Greenwich Standard Time" territory="GH" type="Africa/Accra"/>
        <mapZone other="Greenwich Standard Time" territory="GM" type="Africa/Banjul"/>
        <mapZone other="Greenwich Standard Time" territory="GN" type="Africa/Conakry"/>
        <mapZone other="Greenwich Standard Time" territory="GW" type="Africa/Bissau"/>
        <mapZone other="Greenwich Standard Time" territory="IS" type="Atlantic/Reykjavik"/>
        <mapZone other="Greenwich Standard Time" territory="LR" type="Africa/Monrovia"/>
        <mapZone other="Greenwich Standard Time" territory="ML" type="Africa/Bamako"/>
        <mapZone other="Greenwich Standard Time" territory="MR" type="Africa/Nouakchott"/>
        <mapZone other="Greenwich Standard Time" territory="SH" type="Atlantic/St_Helena"/>
        <mapZone other="Greenwich Standard Time" territory="SL" type="Africa/Freetown"/>
        <mapZone other="Greenwich Standard Time" territory="SN" type="Africa/Dakar"/>
        <mapZone other="Greenwich Standard Time" territory="ST" type="Africa/Sao_Tome"/>
        <mapZone other="Greenwich Standard Time" territory="TG" type="Africa/Lome"/>
        <!--
        (UTC+01:00) Amsterdam, Berlin, Bern, Rome, Stockholm, Vienna 
        -->
        <mapZone other="W. Europe Standard Time" territory="001" type="Europe/Berlin"/>
        <mapZone other="W. Europe Standard Time" territory="AD" type="Europe/Andorra"/>
        <mapZone other="W. Europe Standard Time" territory="AT" type="Europe/Vienna"/>
        <mapZone other="W. Europe Standard Time" territory="CH" type="Europe/Zurich"/>
        <mapZone other="W. Europe Standard Time" territory="DE" type="Europe/Berlin Europe/Busingen"/>
        <mapZone other="W. Europe Standard Time" territory="GI" type="Europe/Gibraltar"/>
        <mapZone other="W. Europe Standard Time" territory="IT" type="Europe/Rome"/>
        <mapZone other="W. Europe Standard Time" territory="LI" type="Europe/Vaduz"/>
        <mapZone other="W. Europe Standard Time" territory="LU" type="Europe/Luxembourg"/>
        <mapZone other="W. Europe Standard Time" territory="MC" type="Europe/Monaco"/>
        <mapZone other="W. Europe Standard Time" territory="MT" type="Europe/Malta"/>
        <mapZone other="W. Europe Standard Time" territory="NL" type="Europe/Amsterdam"/>
        <mapZone other="W. Europe Standard Time" territory="NO" type="Europe/Oslo"/>
        <mapZone other="W. Europe Standard Time" territory="SE" type="Europe/Stockholm"/>
        <mapZone other="W. Europe Standard Time" territory="SJ" type="Arctic/Longyearbyen"/>
        <mapZone other="W. Europe Standard Time" territory="SM" type="Europe/San_Marino"/>
        <mapZone other="W. Europe Standard Time" territory="VA" type="Europe/Vatican"/>
        <!--
        (UTC+01:00) Belgrade, Bratislava, Budapest, Ljubljana, Prague 
        -->
        <mapZone other="Central Europe Standard Time" territory="001" type="Europe/Budapest"/>
        <mapZone other="Central Europe Standard Time" territory="AL" type="Europe/Tirane"/>
        <mapZone other="Central Europe Standard Time" territory="CZ" type="Europe/Prague"/>
        <mapZone other="Central Europe Standard Time" territory="HU" type="Europe/Budapest"/>
        <mapZone other="Central Europe Standard Time" territory="ME" type="Europe/Podgorica"/>
        <mapZone other="Central Europe Standard Time" territory="RS" type="Europe/Belgrade"/>
        <mapZone other="Central Europe Standard Time" territory="SI" type="Europe/Ljubljana"/>
        <mapZone other="Central Europe Standard Time" territory="SK" type="Europe/Bratislava"/>
        <!--  (UTC+01:00) Brussels, Copenhagen, Madrid, Paris  -->
        <mapZone other="Romance Standard Time" territory="001" type="Europe/Paris"/>
        <mapZone other="Romance Standard Time" territory="BE" type="Europe/Brussels"/>
        <mapZone other="Romance Standard Time" territory="DK" type="Europe/Copenhagen"/>
        <mapZone other="Romance Standard Time" territory="ES" type="Europe/Madrid Africa/Ceuta"/>
        <mapZone other="Romance Standard Time" territory="FR" type="Europe/Paris"/>
        <!--  (UTC+01:00) Sarajevo, Skopje, Warsaw, Zagreb  -->
        <mapZone other="Central European Standard Time" territory="001" type="Europe/Warsaw"/>
        <mapZone other="Central European Standard Time" territory="BA" type="Europe/Sarajevo"/>
        <mapZone other="Central European Standard Time" territory="HR" type="Europe/Zagreb"/>
        <mapZone other="Central European Standard Time" territory="MK" type="Europe/Skopje"/>
        <mapZone other="Central European Standard Time" territory="PL" type="Europe/Warsaw"/>
        <!--  (UTC+01:00) West Central Africa  -->
        <mapZone other="W. Central Africa Standard Time" territory="001" type="Africa/Lagos"/>
        <mapZone other="W. Central Africa Standard Time" territory="AO" type="Africa/Luanda"/>
        <mapZone other="W. Central Africa Standard Time" territory="BJ" type="Africa/Porto-Novo"/>
        <mapZone other="W. Central Africa Standard Time" territory="CD" type="Africa/Kinshasa"/>
        <mapZone other="W. Central Africa Standard Time" territory="CF" type="Africa/Bangui"/>
        <mapZone other="W. Central Africa Standard Time" territory="CG" type="Africa/Brazzaville"/>
        <mapZone other="W. Central Africa Standard Time" territory="CM" type="Africa/Douala"/>
        <mapZone other="W. Central Africa Standard Time" territory="DZ" type="Africa/Algiers"/>
        <mapZone other="W. Central Africa Standard Time" territory="GA" type="Africa/Libreville"/>
        <mapZone other="W. Central Africa Standard Time" territory="GQ" type="Africa/Malabo"/>
        <mapZone other="W. Central Africa Standard Time" territory="NE" type="Africa/Niamey"/>
        <mapZone other="W. Central Africa Standard Time" territory="NG" type="Africa/Lagos"/>
        <mapZone other="W. Central Africa Standard Time" territory="TD" type="Africa/Ndjamena"/>
        <mapZone other="W. Central Africa Standard Time" territory="TN" type="Africa/Tunis"/>
        <mapZone other="W. Central Africa Standard Time" territory="ZZ" type="Etc/GMT-1"/>
        <!--  (UTC+01:00) Windhoek  -->
        <mapZone other="Namibia Standard Time" territory="001" type="Africa/Windhoek"/>
        <mapZone other="Namibia Standard Time" territory="NA" type="Africa/Windhoek"/>
        <!--  (UTC+02:00) Amman  -->
        <mapZone other="Jordan Standard Time" territory="001" type="Asia/Amman"/>
        <mapZone other="Jordan Standard Time" territory="JO" type="Asia/Amman"/>
        <!--  (UTC+02:00) Athens, Bucharest  -->
        <mapZone other="GTB Standard Time" territory="001" type="Europe/Bucharest"/>
        <mapZone other="GTB Standard Time" territory="CY" type="Asia/Nicosia"/>
        <mapZone other="GTB Standard Time" territory="GR" type="Europe/Athens"/>
        <mapZone other="GTB Standard Time" territory="RO" type="Europe/Bucharest"/>
        <!--  (UTC+02:00) Beirut  -->
        <mapZone other="Middle East Standard Time" territory="001" type="Asia/Beirut"/>
        <mapZone other="Middle East Standard Time" territory="LB" type="Asia/Beirut"/>
        <!--  (UTC+02:00) Cairo  -->
        <mapZone other="Egypt Standard Time" territory="001" type="Africa/Cairo"/>
        <mapZone other="Egypt Standard Time" territory="EG" type="Africa/Cairo"/>
        <!--  (UTC+02:00) Chisinau  -->
        <mapZone other="E. Europe Standard Time" territory="001" type="Europe/Chisinau"/>
        <mapZone other="E. Europe Standard Time" territory="MD" type="Europe/Chisinau"/>
        <!--  (UTC+02:00) Damascus  -->
        <mapZone other="Syria Standard Time" territory="001" type="Asia/Damascus"/>
        <mapZone other="Syria Standard Time" territory="SY" type="Asia/Damascus"/>
        <!--  (UTC+02:00) Gaza, Hebron  -->
        <mapZone other="West Bank Standard Time" territory="001" type="Asia/Hebron"/>
        <mapZone other="West Bank Standard Time" territory="PS" type="Asia/Hebron Asia/Gaza"/>
        <!--  (UTC+02:00) Harare, Pretoria  -->
        <mapZone other="South Africa Standard Time" territory="001" type="Africa/Johannesburg"/>
        <mapZone other="South Africa Standard Time" territory="BI" type="Africa/Bujumbura"/>
        <mapZone other="South Africa Standard Time" territory="BW" type="Africa/Gaborone"/>
        <mapZone other="South Africa Standard Time" territory="CD" type="Africa/Lubumbashi"/>
        <mapZone other="South Africa Standard Time" territory="LS" type="Africa/Maseru"/>
        <mapZone other="South Africa Standard Time" territory="MW" type="Africa/Blantyre"/>
        <mapZone other="South Africa Standard Time" territory="MZ" type="Africa/Maputo"/>
        <mapZone other="South Africa Standard Time" territory="RW" type="Africa/Kigali"/>
        <mapZone other="South Africa Standard Time" territory="SZ" type="Africa/Mbabane"/>
        <mapZone other="South Africa Standard Time" territory="ZA" type="Africa/Johannesburg"/>
        <mapZone other="South Africa Standard Time" territory="ZM" type="Africa/Lusaka"/>
        <mapZone other="South Africa Standard Time" territory="ZW" type="Africa/Harare"/>
        <mapZone other="South Africa Standard Time" territory="ZZ" type="Etc/GMT-2"/>
        <!--
        (UTC+02:00) Helsinki, Kyiv, Riga, Sofia, Tallinn, Vilnius 
        -->
        <mapZone other="FLE Standard Time" territory="001" type="Europe/Kiev"/>
        <mapZone other="FLE Standard Time" territory="AX" type="Europe/Mariehamn"/>
        <mapZone other="FLE Standard Time" territory="BG" type="Europe/Sofia"/>
        <mapZone other="FLE Standard Time" territory="EE" type="Europe/Tallinn"/>
        <mapZone other="FLE Standard Time" territory="FI" type="Europe/Helsinki"/>
        <mapZone other="FLE Standard Time" territory="LT" type="Europe/Vilnius"/>
        <mapZone other="FLE Standard Time" territory="LV" type="Europe/Riga"/>
        <mapZone other="FLE Standard Time" territory="UA" type="Europe/Kiev Europe/Uzhgorod Europe/Zaporozhye"/>
        <!--  (UTC+02:00) Istanbul  -->
        <mapZone other="Turkey Standard Time" territory="001" type="Europe/Istanbul"/>
        <mapZone other="Turkey Standard Time" territory="TR" type="Europe/Istanbul"/>
        <!--  (UTC+02:00) Jerusalem  -->
        <mapZone other="Israel Standard Time" territory="001" type="Asia/Jerusalem"/>
        <mapZone other="Israel Standard Time" territory="IL" type="Asia/Jerusalem"/>
        <!--  (UTC+02:00) Kaliningrad  -->
        <mapZone other="Kaliningrad Standard Time" territory="001" type="Europe/Kaliningrad"/>
        <mapZone other="Kaliningrad Standard Time" territory="RU" type="Europe/Kaliningrad"/>
        <!--  (UTC+02:00) Tripoli  -->
        <mapZone other="Libya Standard Time" territory="001" type="Africa/Tripoli"/>
        <mapZone other="Libya Standard Time" territory="LY" type="Africa/Tripoli"/>
        <!--  (UTC+03:00) Baghdad  -->
        <mapZone other="Arabic Standard Time" territory="001" type="Asia/Baghdad"/>
        <mapZone other="Arabic Standard Time" territory="IQ" type="Asia/Baghdad"/>
        <!--  (UTC+03:00) Kuwait, Riyadh  -->
        <mapZone other="Arab Standard Time" territory="001" type="Asia/Riyadh"/>
        <mapZone other="Arab Standard Time" territory="BH" type="Asia/Bahrain"/>
        <mapZone other="Arab Standard Time" territory="KW" type="Asia/Kuwait"/>
        <mapZone other="Arab Standard Time" territory="QA" type="Asia/Qatar"/>
        <mapZone other="Arab Standard Time" territory="SA" type="Asia/Riyadh"/>
        <mapZone other="Arab Standard Time" territory="YE" type="Asia/Aden"/>
        <!--  (UTC+03:00) Minsk  -->
        <mapZone other="Belarus Standard Time" territory="001" type="Europe/Minsk"/>
        <mapZone other="Belarus Standard Time" territory="BY" type="Europe/Minsk"/>
        <!--  (UTC+03:00) Moscow, St. Petersburg, Volgograd  -->
        <mapZone other="Russian Standard Time" territory="001" type="Europe/Moscow"/>
        <mapZone other="Russian Standard Time" territory="RU" type="Europe/Moscow Europe/Kirov Europe/Volgograd"/>
        <mapZone other="Russian Standard Time" territory="UA" type="Europe/Simferopol"/>
        <!--  (UTC+03:00) Nairobi  -->
        <mapZone other="E. Africa Standard Time" territory="001" type="Africa/Nairobi"/>
        <mapZone other="E. Africa Standard Time" territory="AQ" type="Antarctica/Syowa"/>
        <mapZone other="E. Africa Standard Time" territory="DJ" type="Africa/Djibouti"/>
        <mapZone other="E. Africa Standard Time" territory="ER" type="Africa/Asmera"/>
        <mapZone other="E. Africa Standard Time" territory="ET" type="Africa/Addis_Ababa"/>
        <mapZone other="E. Africa Standard Time" territory="KE" type="Africa/Nairobi"/>
        <mapZone other="E. Africa Standard Time" territory="KM" type="Indian/Comoro"/>
        <mapZone other="E. Africa Standard Time" territory="MG" type="Indian/Antananarivo"/>
        <mapZone other="E. Africa Standard Time" territory="SD" type="Africa/Khartoum"/>
        <mapZone other="E. Africa Standard Time" territory="SO" type="Africa/Mogadishu"/>
        <mapZone other="E. Africa Standard Time" territory="SS" type="Africa/Juba"/>
        <mapZone other="E. Africa Standard Time" territory="TZ" type="Africa/Dar_es_Salaam"/>
        <mapZone other="E. Africa Standard Time" territory="UG" type="Africa/Kampala"/>
        <mapZone other="E. Africa Standard Time" territory="YT" type="Indian/Mayotte"/>
        <mapZone other="E. Africa Standard Time" territory="ZZ" type="Etc/GMT-3"/>
        <!--  (UTC+03:30) Tehran  -->
        <mapZone other="Iran Standard Time" territory="001" type="Asia/Tehran"/>
        <mapZone other="Iran Standard Time" territory="IR" type="Asia/Tehran"/>
        <!--  (UTC+04:00) Abu Dhabi, Muscat  -->
        <mapZone other="Arabian Standard Time" territory="001" type="Asia/Dubai"/>
        <mapZone other="Arabian Standard Time" territory="AE" type="Asia/Dubai"/>
        <mapZone other="Arabian Standard Time" territory="OM" type="Asia/Muscat"/>
        <mapZone other="Arabian Standard Time" territory="ZZ" type="Etc/GMT-4"/>
        <!--  (UTC+04:00) Astrakhan, Ulyanovsk  -->
        <mapZone other="Astrakhan Standard Time" territory="001" type="Europe/Astrakhan"/>
        <mapZone other="Astrakhan Standard Time" territory="RU" type="Europe/Astrakhan Europe/Saratov Europe/Ulyanovsk"/>
        <!--  (UTC+04:00) Baku  -->
        <mapZone other="Azerbaijan Standard Time" territory="001" type="Asia/Baku"/>
        <mapZone other="Azerbaijan Standard Time" territory="AZ" type="Asia/Baku"/>
        <!--  (UTC+04:00) Izhevsk, Samara  -->
        <mapZone other="Russia Time Zone 3" territory="001" type="Europe/Samara"/>
        <mapZone other="Russia Time Zone 3" territory="RU" type="Europe/Samara"/>
        <!--  (UTC+04:00) Port Louis  -->
        <mapZone other="Mauritius Standard Time" territory="001" type="Indian/Mauritius"/>
        <mapZone other="Mauritius Standard Time" territory="MU" type="Indian/Mauritius"/>
        <mapZone other="Mauritius Standard Time" territory="RE" type="Indian/Reunion"/>
        <mapZone other="Mauritius Standard Time" territory="SC" type="Indian/Mahe"/>
        <!--  (UTC+04:00) Tbilisi  -->
        <mapZone other="Georgian Standard Time" territory="001" type="Asia/Tbilisi"/>
        <mapZone other="Georgian Standard Time" territory="GE" type="Asia/Tbilisi"/>
        <!--  (UTC+04:00) Yerevan  -->
        <mapZone other="Caucasus Standard Time" territory="001" type="Asia/Yerevan"/>
        <mapZone other="Caucasus Standard Time" territory="AM" type="Asia/Yerevan"/>
        <!--  (UTC+04:30) Kabul  -->
        <mapZone other="Afghanistan Standard Time" territory="001" type="Asia/Kabul"/>
        <mapZone other="Afghanistan Standard Time" territory="AF" type="Asia/Kabul"/>
        <!--  (UTC+05:00) Ashgabat, Tashkent  -->
        <mapZone other="West Asia Standard Time" territory="001" type="Asia/Tashkent"/>
        <mapZone other="West Asia Standard Time" territory="AQ" type="Antarctica/Mawson"/>
        <mapZone other="West Asia Standard Time" territory="KZ" type="Asia/Oral Asia/Aqtau Asia/Aqtobe Asia/Atyrau"/>
        <mapZone other="West Asia Standard Time" territory="MV" type="Indian/Maldives"/>
        <mapZone other="West Asia Standard Time" territory="TF" type="Indian/Kerguelen"/>
        <mapZone other="West Asia Standard Time" territory="TJ" type="Asia/Dushanbe"/>
        <mapZone other="West Asia Standard Time" territory="TM" type="Asia/Ashgabat"/>
        <mapZone other="West Asia Standard Time" territory="UZ" type="Asia/Tashkent Asia/Samarkand"/>
        <mapZone other="West Asia Standard Time" territory="ZZ" type="Etc/GMT-5"/>
        <!--  (UTC+05:00) Ekaterinburg  -->
        <mapZone other="Ekaterinburg Standard Time" territory="001" type="Asia/Yekaterinburg"/>
        <mapZone other="Ekaterinburg Standard Time" territory="RU" type="Asia/Yekaterinburg"/>
        <!--  (UTC+05:00) Islamabad, Karachi  -->
        <mapZone other="Pakistan Standard Time" territory="001" type="Asia/Karachi"/>
        <mapZone other="Pakistan Standard Time" territory="PK" type="Asia/Karachi"/>
        <!--  (UTC+05:30) Chennai, Kolkata, Mumbai, New Delhi  -->
        <mapZone other="India Standard Time" territory="001" type="Asia/Calcutta"/>
        <mapZone other="India Standard Time" territory="IN" type="Asia/Calcutta"/>
        <!--  (UTC+05:30) Sri Jayawardenepura  -->
        <mapZone other="Sri Lanka Standard Time" territory="001" type="Asia/Colombo"/>
        <mapZone other="Sri Lanka Standard Time" territory="LK" type="Asia/Colombo"/>
        <!--  (UTC+05:45) Kathmandu  -->
        <mapZone other="Nepal Standard Time" territory="001" type="Asia/Katmandu"/>
        <mapZone other="Nepal Standard Time" territory="NP" type="Asia/Katmandu"/>
        <!--  (UTC+06:00) Astana  -->
        <mapZone other="Central Asia Standard Time" territory="001" type="Asia/Almaty"/>
        <mapZone other="Central Asia Standard Time" territory="AQ" type="Antarctica/Vostok"/>
        <mapZone other="Central Asia Standard Time" territory="CN" type="Asia/Urumqi"/>
        <mapZone other="Central Asia Standard Time" territory="IO" type="Indian/Chagos"/>
        <mapZone other="Central Asia Standard Time" territory="KG" type="Asia/Bishkek"/>
        <mapZone other="Central Asia Standard Time" territory="KZ" type="Asia/Almaty Asia/Qyzylorda"/>
        <mapZone other="Central Asia Standard Time" territory="ZZ" type="Etc/GMT-6"/>
        <!--  (UTC+06:00) Dhaka  -->
        <mapZone other="Bangladesh Standard Time" territory="001" type="Asia/Dhaka"/>
        <mapZone other="Bangladesh Standard Time" territory="BD" type="Asia/Dhaka"/>
        <mapZone other="Bangladesh Standard Time" territory="BT" type="Asia/Thimphu"/>
        <!--  (UTC+06:00) Omsk  -->
        <mapZone other="Omsk Standard Time" territory="001" type="Asia/Omsk"/>
        <mapZone other="Omsk Standard Time" territory="RU" type="Asia/Omsk"/>
        <!--  (UTC+06:30) Yangon (Rangoon)  -->
        <mapZone other="Myanmar Standard Time" territory="001" type="Asia/Rangoon"/>
        <mapZone other="Myanmar Standard Time" territory="CC" type="Indian/Cocos"/>
        <mapZone other="Myanmar Standard Time" territory="MM" type="Asia/Rangoon"/>
        <!--  (UTC+07:00) Bangkok, Hanoi, Jakarta  -->
        <mapZone other="SE Asia Standard Time" territory="001" type="Asia/Bangkok"/>
        <mapZone other="SE Asia Standard Time" territory="AQ" type="Antarctica/Davis"/>
        <mapZone other="SE Asia Standard Time" territory="CX" type="Indian/Christmas"/>
        <mapZone other="SE Asia Standard Time" territory="ID" type="Asia/Jakarta Asia/Pontianak"/>
        <mapZone other="SE Asia Standard Time" territory="KH" type="Asia/Phnom_Penh"/>
        <mapZone other="SE Asia Standard Time" territory="LA" type="Asia/Vientiane"/>
        <mapZone other="SE Asia Standard Time" territory="TH" type="Asia/Bangkok"/>
        <mapZone other="SE Asia Standard Time" territory="VN" type="Asia/Saigon"/>
        <mapZone other="SE Asia Standard Time" territory="ZZ" type="Etc/GMT-7"/>
        <!--  (UTC+07:00) Barnaul, Gorno-Altaysk  -->
        <mapZone other="Altai Standard Time" territory="001" type="Asia/Barnaul"/>
        <mapZone other="Altai Standard Time" territory="RU" type="Asia/Barnaul"/>
        <!--  (UTC+07:00) Hovd  -->
        <mapZone other="W. Mongolia Standard Time" territory="001" type="Asia/Hovd"/>
        <mapZone other="W. Mongolia Standard Time" territory="MN" type="Asia/Hovd"/>
        <!--  (UTC+07:00) Krasnoyarsk  -->
        <mapZone other="North Asia Standard Time" territory="001" type="Asia/Krasnoyarsk"/>
        <mapZone other="North Asia Standard Time" territory="RU" type="Asia/Krasnoyarsk Asia/Novokuznetsk"/>
        <!--  (UTC+07:00) Novosibirsk  -->
        <mapZone other="N. Central Asia Standard Time" territory="001" type="Asia/Novosibirsk"/>
        <mapZone other="N. Central Asia Standard Time" territory="RU" type="Asia/Novosibirsk"/>
        <!--  (UTC+07:00) Tomsk  -->
        <mapZone other="Tomsk Standard Time" territory="001" type="Asia/Tomsk"/>
        <mapZone other="Tomsk Standard Time" territory="RU" type="Asia/Tomsk"/>
        <!--  (UTC+08:00) Beijing, Chongqing, Hong Kong, Urumqi  -->
        <mapZone other="China Standard Time" territory="001" type="Asia/Shanghai"/>
        <mapZone other="China Standard Time" territory="CN" type="Asia/Shanghai"/>
        <mapZone other="China Standard Time" territory="HK" type="Asia/Hong_Kong"/>
        <mapZone other="China Standard Time" territory="MO" type="Asia/Macau"/>
        <!--  (UTC+08:00) Irkutsk  -->
        <mapZone other="North Asia East Standard Time" territory="001" type="Asia/Irkutsk"/>
        <mapZone other="North Asia East Standard Time" territory="RU" type="Asia/Irkutsk"/>
        <!--  (UTC+08:00) Kuala Lumpur, Singapore  -->
        <mapZone other="Singapore Standard Time" territory="001" type="Asia/Singapore"/>
        <mapZone other="Singapore Standard Time" territory="BN" type="Asia/Brunei"/>
        <mapZone other="Singapore Standard Time" territory="ID" type="Asia/Makassar"/>
        <mapZone other="Singapore Standard Time" territory="MY" type="Asia/Kuala_Lumpur Asia/Kuching"/>
        <mapZone other="Singapore Standard Time" territory="PH" type="Asia/Manila"/>
        <mapZone other="Singapore Standard Time" territory="SG" type="Asia/Singapore"/>
        <mapZone other="Singapore Standard Time" territory="ZZ" type="Etc/GMT-8"/>
        <!--  (UTC+08:00) Perth  -->
        <mapZone other="W. Australia Standard Time" territory="001" type="Australia/Perth"/>
        <mapZone other="W. Australia Standard Time" territory="AU" type="Australia/Perth"/>
        <!--  (UTC+08:00) Taipei  -->
        <mapZone other="Taipei Standard Time" territory="001" type="Asia/Taipei"/>
        <mapZone other="Taipei Standard Time" territory="TW" type="Asia/Taipei"/>
        <!--  (UTC+08:00) Ulaanbaatar  -->
        <mapZone other="Ulaanbaatar Standard Time" territory="001" type="Asia/Ulaanbaatar"/>
        <mapZone other="Ulaanbaatar Standard Time" territory="MN" type="Asia/Ulaanbaatar Asia/Choibalsan"/>
        <!--  (UTC+08:30) Pyongyang  -->
        <mapZone other="North Korea Standard Time" territory="001" type="Asia/Pyongyang"/>
        <mapZone other="North Korea Standard Time" territory="KP" type="Asia/Pyongyang"/>
        <!--  (UTC+08:45) Eucla  -->
        <mapZone other="Aus Central W. Standard Time" territory="001" type="Australia/Eucla"/>
        <mapZone other="Aus Central W. Standard Time" territory="AU" type="Australia/Eucla"/>
        <!--  (UTC+09:00) Chita  -->
        <mapZone other="Transbaikal Standard Time" territory="001" type="Asia/Chita"/>
        <mapZone other="Transbaikal Standard Time" territory="RU" type="Asia/Chita"/>
        <!--  (UTC+09:00) Osaka, Sapporo, Tokyo  -->
        <mapZone other="Tokyo Standard Time" territory="001" type="Asia/Tokyo"/>
        <mapZone other="Tokyo Standard Time" territory="ID" type="Asia/Jayapura"/>
        <mapZone other="Tokyo Standard Time" territory="JP" type="Asia/Tokyo"/>
        <mapZone other="Tokyo Standard Time" territory="PW" type="Pacific/Palau"/>
        <mapZone other="Tokyo Standard Time" territory="TL" type="Asia/Dili"/>
        <mapZone other="Tokyo Standard Time" territory="ZZ" type="Etc/GMT-9"/>
        <!--  (UTC+09:00) Seoul  -->
        <mapZone other="Korea Standard Time" territory="001" type="Asia/Seoul"/>
        <mapZone other="Korea Standard Time" territory="KR" type="Asia/Seoul"/>
        <!--  (UTC+09:00) Yakutsk  -->
        <mapZone other="Yakutsk Standard Time" territory="001" type="Asia/Yakutsk"/>
        <mapZone other="Yakutsk Standard Time" territory="RU" type="Asia/Yakutsk Asia/Khandyga"/>
        <!--  (UTC+09:30) Adelaide  -->
        <mapZone other="Cen. Australia Standard Time" territory="001" type="Australia/Adelaide"/>
        <mapZone other="Cen. Australia Standard Time" territory="AU" type="Australia/Adelaide Australia/Broken_Hill"/>
        <!--  (UTC+09:30) Darwin  -->
        <mapZone other="AUS Central Standard Time" territory="001" type="Australia/Darwin"/>
        <mapZone other="AUS Central Standard Time" territory="AU" type="Australia/Darwin"/>
        <!--  (UTC+10:00) Brisbane  -->
        <mapZone other="E. Australia Standard Time" territory="001" type="Australia/Brisbane"/>
        <mapZone other="E. Australia Standard Time" territory="AU" type="Australia/Brisbane Australia/Lindeman"/>
        <!--  (UTC+10:00) Canberra, Melbourne, Sydney  -->
        <mapZone other="AUS Eastern Standard Time" territory="001" type="Australia/Sydney"/>
        <mapZone other="AUS Eastern Standard Time" territory="AU" type="Australia/Sydney Australia/Melbourne"/>
        <!--  (UTC+10:00) Guam, Port Moresby  -->
        <mapZone other="West Pacific Standard Time" territory="001" type="Pacific/Port_Moresby"/>
        <mapZone other="West Pacific Standard Time" territory="AQ" type="Antarctica/DumontDUrville"/>
        <mapZone other="West Pacific Standard Time" territory="FM" type="Pacific/Truk"/>
        <mapZone other="West Pacific Standard Time" territory="GU" type="Pacific/Guam"/>
        <mapZone other="West Pacific Standard Time" territory="MP" type="Pacific/Saipan"/>
        <mapZone other="West Pacific Standard Time" territory="PG" type="Pacific/Port_Moresby"/>
        <mapZone other="West Pacific Standard Time" territory="ZZ" type="Etc/GMT-10"/>
        <!--  (UTC+10:00) Hobart  -->
        <mapZone other="Tasmania Standard Time" territory="001" type="Australia/Hobart"/>
        <mapZone other="Tasmania Standard Time" territory="AU" type="Australia/Hobart Australia/Currie"/>
        <!--  (UTC+10:00) Vladivostok  -->
        <mapZone other="Vladivostok Standard Time" territory="001" type="Asia/Vladivostok"/>
        <mapZone other="Vladivostok Standard Time" territory="RU" type="Asia/Vladivostok Asia/Ust-Nera"/>
        <!--  (UTC+10:30) Lord Howe Island  -->
        <mapZone other="Lord Howe Standard Time" territory="001" type="Australia/Lord_Howe"/>
        <mapZone other="Lord Howe Standard Time" territory="AU" type="Australia/Lord_Howe"/>
        <!--  (UTC+11:00) Bougainville Island  -->
        <mapZone other="Bougainville Standard Time" territory="001" type="Pacific/Bougainville"/>
        <mapZone other="Bougainville Standard Time" territory="PG" type="Pacific/Bougainville"/>
        <!--  (UTC+11:00) Chokurdakh  -->
        <mapZone other="Russia Time Zone 10" territory="001" type="Asia/Srednekolymsk"/>
        <mapZone other="Russia Time Zone 10" territory="RU" type="Asia/Srednekolymsk"/>
        <!--  (UTC+11:00) Magadan  -->
        <mapZone other="Magadan Standard Time" territory="001" type="Asia/Magadan"/>
        <mapZone other="Magadan Standard Time" territory="RU" type="Asia/Magadan"/>
        <!--  (UTC+11:00) Norfolk Island  -->
        <mapZone other="Norfolk Standard Time" territory="001" type="Pacific/Norfolk"/>
        <mapZone other="Norfolk Standard Time" territory="NF" type="Pacific/Norfolk"/>
        <!--  (UTC+11:00) Sakhalin  -->
        <mapZone other="Sakhalin Standard Time" territory="001" type="Asia/Sakhalin"/>
        <mapZone other="Sakhalin Standard Time" territory="RU" type="Asia/Sakhalin"/>
        <!--  (UTC+11:00) Solomon Is., New Caledonia  -->
        <mapZone other="Central Pacific Standard Time" territory="001" type="Pacific/Guadalcanal"/>
        <mapZone other="Central Pacific Standard Time" territory="AQ" type="Antarctica/Casey"/>
        <mapZone other="Central Pacific Standard Time" territory="AU" type="Antarctica/Macquarie"/>
        <mapZone other="Central Pacific Standard Time" territory="FM" type="Pacific/Ponape Pacific/Kosrae"/>
        <mapZone other="Central Pacific Standard Time" territory="NC" type="Pacific/Noumea"/>
        <mapZone other="Central Pacific Standard Time" territory="SB" type="Pacific/Guadalcanal"/>
        <mapZone other="Central Pacific Standard Time" territory="VU" type="Pacific/Efate"/>
        <mapZone other="Central Pacific Standard Time" territory="ZZ" type="Etc/GMT-11"/>
        <!--  (UTC+12:00) Anadyr, Petropavlovsk-Kamchatsky  -->
        <mapZone other="Russia Time Zone 11" territory="001" type="Asia/Kamchatka"/>
        <mapZone other="Russia Time Zone 11" territory="RU" type="Asia/Kamchatka Asia/Anadyr"/>
        <!--  (UTC+12:00) Auckland, Wellington  -->
        <mapZone other="New Zealand Standard Time" territory="001" type="Pacific/Auckland"/>
        <mapZone other="New Zealand Standard Time" territory="AQ" type="Antarctica/McMurdo"/>
        <mapZone other="New Zealand Standard Time" territory="NZ" type="Pacific/Auckland"/>
        <!--  (UTC+12:00) Coordinated Universal Time+12  -->
        <mapZone other="UTC+12" territory="001" type="Etc/GMT-12"/>
        <mapZone other="UTC+12" territory="KI" type="Pacific/Tarawa"/>
        <mapZone other="UTC+12" territory="MH" type="Pacific/Majuro Pacific/Kwajalein"/>
        <mapZone other="UTC+12" territory="NR" type="Pacific/Nauru"/>
        <mapZone other="UTC+12" territory="TV" type="Pacific/Funafuti"/>
        <mapZone other="UTC+12" territory="UM" type="Pacific/Wake"/>
        <mapZone other="UTC+12" territory="WF" type="Pacific/Wallis"/>
        <mapZone other="UTC+12" territory="ZZ" type="Etc/GMT-12"/>
        <!--  (UTC+12:00) Fiji  -->
        <mapZone other="Fiji Standard Time" territory="001" type="Pacific/Fiji"/>
        <mapZone other="Fiji Standard Time" territory="FJ" type="Pacific/Fiji"/>
        <!--  (UTC+12:45) Chatham Islands  -->
        <mapZone other="Chatham Islands Standard Time" territory="001" type="Pacific/Chatham"/>
        <mapZone other="Chatham Islands Standard Time" territory="NZ" type="Pacific/Chatham"/>
        <!--  (UTC+13:00) Nuku'alofa  -->
        <mapZone other="Tonga Standard Time" territory="001" type="Pacific/Tongatapu"/>
        <mapZone other="Tonga Standard Time" territory="KI" type="Pacific/Enderbury"/>
        <mapZone other="Tonga Standard Time" territory="TK" type="Pacific/Fakaofo"/>
        <mapZone other="Tonga Standard Time" territory="TO" type="Pacific/Tongatapu"/>
        <mapZone other="Tonga Standard Time" territory="ZZ" type="Etc/GMT-13"/>
        <!--  (UTC+13:00) Samoa  -->
        <mapZone other="Samoa Standard Time" territory="001" type="Pacific/Apia"/>
        <mapZone other="Samoa Standard Time" territory="WS" type="Pacific/Apia"/>
        <!--  (UTC+14:00) Kiritimati Island  -->
        <mapZone other="Line Islands Standard Time" territory="001" type="Pacific/Kiritimati"/>
        <mapZone other="Line Islands Standard Time" territory="KI" type="Pacific/Kiritimati"/>
        <mapZone other="Line Islands Standard Time" territory="ZZ" type="Etc/GMT-14"/>
        </mapTimezones>
        </windowsZones>
        </supplementalData>`;
}