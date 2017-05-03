/**
 * Copyright 2017
 * MIT License
 * User sample
 */
import phabricator.api;
import phabricator.common;
import sample.common;
import std.stdio;

// main entry
void main(string[] args)
{
    auto settings = getSettings(args);
    auto api = construct!UserAPI(settings);
    auto me = api.whoami();
    writeln(me);
    writeln(me[ResultKey]["userName"].str);
    auto all = api.activeUsers();
    foreach (item; all[ResultKey][DataKey].array)
    {
        writeln(item[FieldsKey]["username"].str);
    }
}
