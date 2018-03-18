/**
 * Copyright 2018
 * MIT License
 * Common operations
 */
module phabricator.common;
import phabricator.api;
import std.file: exists, readText;
import std.string: endsWith, indexOf, split, startsWith;

// Result key
public enum ResultKey = "result";

// Content key
public enum ContentKey = "content";

// Data key
public enum DataKey = "data";

// cursor key
public enum CursorKey = "cursor";

// after key
public enum AfterKey = "after";

// Custom fields
private enum CustomField = "custom.custom:";

// Index field
public enum IndexField = CustomField ~ "index";

// fields key
public enum FieldsKey = "fields";

// status key
public enum StatusKey = "status";

// PHID object identifiers
public enum PHID = "phid";

// Attachments key
public enum AttachKey = "attachments";

// Raw key
public enum RawKey = "raw";

/**
 * Settings to construct apis from
 */
public struct Settings
{
    // host/url to connect to
    string url;

    // conduit token
    string token;
}

/**
 * Create a new api from settings
 */
public static T construct(T : PhabricatorAPI)(Settings settings)
    if (is(typeof(new T()) == T))
{
    auto api = new T();
    api.url = settings.url;
    api.token = settings.token;
    return api;
}

/**
 * Load environment variables
 */
public static string[string] loadEnvironmentFile(string envFile, string filter)
{
    string[string] vars;
    loadEnvironmentFile(vars, envFile, filter);
    return vars;
}

/**
 * Load into an existing associative array
 */
public static void loadEnvironmentFile(string[string] vars, string envFile, string filter)
{
    if (exists(envFile))
    {
        auto useFilter = filter;
        if (useFilter == null)
        {
            useFilter = "";
        }
        auto text = readText(envFile);
        foreach (string line; text.split("\n"))
        {
            loadSetting(vars, line, filter);
        }
    }
}

/**
 * Load settings
 */
public static void loadSetting(string[string] vars, string line, string filter)
{
    if (line.startsWith(filter))
    {
        auto segment = line[filter.length..line.length];
        auto idx = segment.indexOf("=");
        if (idx > 0)
        {
            auto key = segment[0..idx];
            auto val = segment[idx + 1..segment.length];
            if (val.startsWith("\"") && val.endsWith("\""))
            {
                val = val[1..val.length - 1];
            }

            vars[key] = val;
        }
    }
}
