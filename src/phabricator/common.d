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
