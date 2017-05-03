/**
 * Copyright 2017
 * MIT License
 * Tasking sample
 */
import phabricator.tasks;
import sample.common;
import std.stdio;

// Range offset
private enum Offset = 50;

// main entry
void main(string[] args)
{
    auto settings = getSettings(args);
    int current = 1;
    while (current < 2200)
    {
        foreach (restrict; restricted(settings, current, Offset))
        {
            writeln("unable to find information about " ~ restrict);
        }

        current = current + Offset;
    }
}
