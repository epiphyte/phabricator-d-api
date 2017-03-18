/**
 * Copyright 2017
 * MIT License
 * Tasking sample
 */
import phabricator.tasks;
import sample.common;
import std.stdio;

// main entry
void main(string[] args)
{
    auto settings = getSettings(args);
    if (overdue(settings))
    {
        writeln("overdue tasks updated");
    }
    else
    {
        writeln("failed to update overdue tasks");
    }
}
