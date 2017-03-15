/**
 * Copyright 2017
 * MIT License
 * Indexing (custom field) operations
 */
module phabricator.indexing;
import phabricator.api;
import phabricator.common;
import std.algorithm: sort;
import std.json;
import std.stdio;

/**
 * Get a list of all unique, sorted index values
 */
public static string[] getIndexValues(Settings settings)
{
    try
    {
        JSONValue[string] objs;
        auto maniphest = construct!ManiphestAPI(settings);
        foreach (obj; maniphest.all()[ResultKey][DataKey].array)
        {
            auto fields = obj[FieldsKey];
            if (IndexField in fields)
            {
                auto val = fields[IndexField];
                if (!val.isNull)
                {
                    objs[val.str] = obj;
                }
            }
        }

        string[] vals;
        foreach (val; objs.keys.sort!("a < b"))
        {
            vals ~= val;
        }

        return vals;
    }
    catch (Exception e)
    {
        writeln(e);
        return [];
    }
}
