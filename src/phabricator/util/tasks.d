/**
 * Copyright 2016
 * MIT License
 * Task helpers
 */
module phabricator.util.tasks;
import phabricator.api;
import phabricator.common;
import std.algorithm: sort;
import std.conv: to;
import std.datetime;
import std.json;
import std.stdio: writeln;

// Id field for tasks
private enum IdField = "id";

/**
 * Get a task id e.g. T[0-9]+
 */
private static string getId(JSONValue task)
{
    return "T" ~ to!string(task[IdField].integer);
}

/**
 * Move all tasks from a query to a project
 */
public static int queryToProject(Settings settings,
                                   string query,
                                   string projectPHID)
{
    int count = 0;
    try
    {
        auto maniphest = construct!ManiphestAPI(settings);
        auto queried = maniphest.byQueryKey(query)[ResultKey][DataKey];
        foreach (task; queried.array)
        {
            maniphest.addProject(task[PHID].str, projectPHID);
            count++;
        }
    }
    catch (Exception e)
    {
        count = count * -1;
    }

    return count;
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
                        auto taskStr = task[PHID].str;
                        maniphest.addProject(taskStr, projectPHID);
                        maniphest.comment(taskStr,
                                          "task updated due to inactivity");
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
 * Detects restricted tasks
 */
public static string[] restricted(Settings settings, int start, int page)
{
    try
    {
        if (page < 0)
        {
            return [];
        }

        int paging = 0;
        int[] ids;
        bool[long] matched;
        while (paging <= page)
        {
            ids ~= start + paging;
            matched[start + paging] = false;
            paging++;
        }

        auto maniphest = construct!ManiphestAPI(settings);
        auto raw = maniphest.byIds(ids);
        auto all = raw[ResultKey][DataKey];
        foreach (task; all.array)
        {
            if (FieldsKey in task)
            {
                auto id = task[IdField].integer;
                if (id in matched)
                {
                    matched[id] = true;
                }
                else
                {
                    matched[id] = false;
                }
            }
        }

        string[] results;
        foreach (match; matched.keys.sort!())
        {
            if (!matched[match])
            {
                results ~= to!string(match);
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
 * Tasks for a project needing action
 */
public static string[] actionNeeded(Settings settings,
                                    string projectPHID,
                                    string userPHID)
{
    try
    {
        auto users = construct!UserAPI(settings);
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
