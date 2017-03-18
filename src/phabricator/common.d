/**
 * Copyright 2017
 * MIT License
 * Common operations
 */
module phabricator.common;
import phabricator.api;
import std.base64;

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

// Due date field
public enum DueDate = CustomField ~ "duedate";

// fields key
public enum FieldsKey = "fields";

// status key
public enum StatusKey = "status";

// PHID object identifiers
public enum PHID = "phid";

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
 * Convert diffusion artifact to object
 */
public static string getDiffusion(Settings settings,
                                  string path,
                                  string callsign,
                                  string branch)
{
    auto diff = construct!DiffusionAPI(settings);
    auto cnt = diff.fileContentByPathBranch(path, callsign, branch);
    auto file = construct!FileAPI(settings);
    auto download = file.download(cnt[ResultKey]["filePHID"].str);
    ubyte[] bytes = Base64.decode(download[ResultKey].str);
    return cast(string)bytes;
}
