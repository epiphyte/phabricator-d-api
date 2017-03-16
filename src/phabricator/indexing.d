/**
 * Copyright 2017
 * MIT License
 * Indexing (custom field) operations
 */
module phabricator.indexing;
import phabricator.api;
import phabricator.common;
import std.json;
import std.stdio;

/**
 * Get a list of all unique, sorted index values
 */
public static int[string] getIndexValues(Settings settings)
{
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

        return objs;
    }
    catch (Exception e)
    {
        int[string] vals;
        writeln(e);
        return vals;
    }
}
