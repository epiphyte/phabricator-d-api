/**
 * Copyright 2017
 * MIT License
 * Repo (CSV) to wiki converter
 */
import phabricator.common;
import phabricator.conv2wiki;
import std.getopt;
import std.stdio;

private enum Header = "
> this page is maintained by a bot
> **DO NOT** edit this page directly
";

// main entry
void main(string[] args)
{
    string host;
    string token;
    string callsign;
    string branch;
    string path;
    string slug;
    string title;
    auto opts = getopt(args,
                       std.getopt.config.required,
                       "host",
                       &host,
                       std.getopt.config.required,
                       "token",
                       &token,
                       std.getopt.config.required,
                       "callsign",
                       &callsign,
                       std.getopt.config.required,
                       "branch",
                       &branch,
                       std.getopt.config.required,
                       "path",
                       &path,
                       std.getopt.config.required,
                       "slug",
                       &slug,
                       std.getopt.config.required,
                       "title",
                       &title);
    auto settings = Settings();
    settings.url = host;
    settings.token = token;
    if (wikiDiffusion(settings, Header, slug, title, path, callsign, branch))
    {
        writeln("wiki updated");
    }
    else
    {
        writeln("unable to update page: " ~ slug);
    }
}
