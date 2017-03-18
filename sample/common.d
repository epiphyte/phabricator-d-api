/**
 * Copyright 2017
 * MIT License
 * Common settings definition
 */
module sample.common;
import phabricator.common;
import std.getopt;

/**
 * Get settings
 */
Settings getSettings(string[] args)
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
    return settings;
}
