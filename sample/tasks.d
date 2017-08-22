/**
 * Copyright 2017
 * MIT License
 * Tasking sample
 */
import phabricator.api;
import phabricator.common;
import phabricator.util.tasks;
import sample.common;
import std.conv: to;
import std.stdio;

// main entry
void main(string[] args)
{
    auto settings = getSettings(args);
    int count = 0;
    auto api = construct!ManiphestAPI(settings);
    foreach (task; api.all()[ResultKey][DataKey].array)
    {
        count++;
    }

    foreach (restrict; restricted(settings, 1, 2200))
    {
        writeln("unable to find information about " ~ restrict);
    }

    writeln("task count: " ~ to!string(count));
}
