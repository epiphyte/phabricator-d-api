/**
 * Copyright 2017
 * MIT License
 * Common operations
 */
module phabricator.common;
import phabricator.api;

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
