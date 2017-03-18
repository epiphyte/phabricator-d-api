/**
 * Copyright 2016
 * MIT License
 * Task helpers
 */
module phabricator.tasks;
import phabricator.api;
import phabricator.common;
import std.conv: to;
import std.datetime;
import std.json;
import std.stdio: writeln;

/**
 * Get a task id e.g. T[0-9]+
 */
private static string getId(JSONValue task)
{
    return "T" ~ to!string(task["id"].integer);
}

/**
 * Unmodified task handling
 */
public static bool unmodified(Settings settings,
                                  string projectPHID,
                                  int months)
{
    try
    {
        auto maniphest = construct!ManiphestAPI(settings);
        auto all = maniphest.openProject(projectPHID)[ResultKey][DataKey];
        foreach (task; all.array)
        {
            maniphest.invalid(task[PHID].str);
        }

        string[] projs;
        auto active = construct!ProjectAPI(settings).active();
        auto now = Clock.currTime();
        foreach (proj; active[ResultKey][DataKey].array)
        {
            auto open = maniphest.openProject(proj[PHID].str);
            foreach (task; open[ResultKey][DataKey].array)
            {
                if (FieldsKey in task)
                {
                    auto fields = task[FieldsKey];
                    auto modified = fields["dateModified"].integer;
                    auto actual = SysTime.fromUnixTime(modified);
                    actual.add!"months"(months);
                    if (actual < now)
                    {
                        maniphest.addProject(task[PHID].str, projectPHID);
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

/**
 * Tasks for a project needing action
 */
public static string[] actionNeeded(Settings settings,
                                    string projectPHID)
{
    try
    {
        auto users = construct!UserAPI(settings);
        auto userPHID = users.whoami()[ResultKey][PHID].str;
        auto maniphest = construct!ManiphestAPI(settings);
        auto raw = maniphest.openSubscribedProject(projectPHID, userPHID);
        auto all = raw[ResultKey][DataKey];
        string[] results;
        foreach (task; all.array)
        {
            if (FieldsKey in task)
            {
                auto fields = task[FieldsKey];
                if (StatusKey in fields)
                {
                    auto status = fields[StatusKey];
                    if (status["value"].str == "actionneeded")
                    {
                        results ~= getId(task);
                    }
                }
            }
        }

        return results;
    }
    catch (Exception e)
    {
        writeln(e);
        return [];
    }
}

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
