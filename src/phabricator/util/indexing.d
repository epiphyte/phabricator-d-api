/**
 * Copyright 2017
 * MIT License
 * Indexing (custom field) operations
 */
module phabricator.util.indexing;
import phabricator.api;
import phabricator.common;
import std.json;
import std.stdio;

/**
 * An index item response from phabricator
 */
public class IndexItem
{
    // tasks
    private string[] phids = [];

    // add a new entry
    public void add(string entry)
    {
        this.phids ~= entry;
    }

    // get tasks of this object
    public string[] tasks()
    {
        return this.phids.dup;
    }
}

/**
 * Get a list of all unique, sorted index values
 */
public static IndexItem[string] getIndexValues(Settings settings)
{
    try
    {
        IndexItem[string] objs;
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
                        objs[val.str] = new IndexItem();
                    }

                    objs[val.str].add(obj[PHID].str);
                }
            }
        }

        return objs;
    }
    catch (Exception e)
    {
        IndexItem[string] vals;
        writeln(e);
        return vals;
    }
}
