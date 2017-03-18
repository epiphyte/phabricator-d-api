/**
 * Copyright 2017
 * MIT License
 * Tasking sample
 */
import phabricator.common;
import phabricator.tasks;
import std.getopt;
import std.stdio;

// main entry
void main(string[] args)
{
    string host;
    string token;
    auto opts = getopt(args,
                       std.getopt.config.required,
                       "host",
                       &host,
                       std.getopt.config.required,
                       "token",
                       &token);
    auto settings = Settings();
    settings.url = host;
    settings.token = token;
    if (overdue(settings))
    {
        writeln("overdue tasks updated");
    }
    else
    {
        writeln("failed to update overdue tasks");
    }
}
