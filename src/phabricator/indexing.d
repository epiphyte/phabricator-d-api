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
public static int[string] getIndexValues(Settings settings)
{
    int[string] vals;
    try
    {
        int[string] objs;
        auto maniphest = construct!ManiphestAPI(settings);
        foreach (obj; maniphest.all()[ResultKey][DataKey].array)
        {
            auto fields = obj[FieldsKey];
            if (IndexField in fields)
            {
                auto val = fields[IndexField];
                if (!val.isNull)
                {
                    if (val.str !in objs)
                    {
                        objs[val.str] = 0;
                    }

                    objs[val.str]++;
                }
            }
        }

        foreach (val; objs.keys.sort!("a < b"))
        {
            vals[val] = objs[val];
        }

        return vals;
    }
    catch (Exception e)
    {
        writeln(e);
    }

    return vals;
}
