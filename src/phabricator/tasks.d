/**
 * Copyright 2016
 * MIT License
 * Task helpers
 */
module phabricator.tasks;
import phabricator.api;
import phabricator.common;
import std.datetime;
import std.json;
import std.stdio: writeln;

/**
 * Comment on overdue tasks
 */
public static bool overdue(Settings settings)
{
    try
    {
        auto now = Clock.currTime().toUnixTime();
        auto maniphest = construct!ManiphestAPI(settings);
        auto data = maniphest.open()[ResultKey][DataKey];
        foreach (task; data.array)
        {
            if (FieldsKey in task)
            {
                auto fields = task[FieldsKey];
                if (DueDate in fields)
                {
                    auto val = fields[DueDate];
                    if (!val.isNull)
                    {
                        auto due = val.integer;
                        if (due < now)
                        {
                            maniphest.comment(task[PHID].str,
                                              "this task is overdue");
                        }
                    }
                }
            }
        }

        return true;
    }
    catch (Exception e)
    {
        writeln(e);
        return false;
    }
}
