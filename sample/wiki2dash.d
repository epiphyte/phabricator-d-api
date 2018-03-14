/**
 * Copyright 2018
 * MIT License
 * Wiki to dashboard utility sample
 */
import phabricator.common;
import phabricator.util.wiki2dash;
import std.getopt;
import std.stdio;

// main entry
void main(string[] args)
{
    string host;
    string token;
    string phid;
    string widget;
    auto opts = getopt(args,
                       std.getopt.config.required,
                       "host",
                       &host,
                       std.getopt.config.required,
                       "token",
                       &token,
                       std.getopt.config.required,
                       "phid",
                       &phid,
                       std.getopt.config.required,
                       "widget",
                       &widget,
                       std.getopt.config.required);
    auto settings = Settings();
    settings.url = host;
    settings.token = token;
    if (convertToDashboard(settings, phid, widget))
    {
        writeln("wiki updated");
    }
    else
    {
        writeln("unable to update page: " ~ phid);
    }
}
