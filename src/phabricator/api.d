/**
 * Copyright 2017
 * MIT License
 * Phabricator Conduit API
 */
module phabricator.api;
import core.time;
import phabricator.common;
import std.conv: to;
import std.json;
import std.net.curl;
import std.string: startsWith, toUpper;
import std.typecons;
import std.uri;

// error code key
private enum ErrorCode = "error_code";

/**
 * Generalized exceptions
 */
public class PhabricatorAPIException : Exception
{
    @property public string content;
    this(string msg, string content = null)
    {
        super(msg);
        this.content = content;
    }
}

///
version(PhabUnitTest)
{
    unittest
    {
        auto error = new PhabricatorAPIException("test");
        assert(error.msg == "test");
        assert(error.content == null);
        error = new PhabricatorAPIException("test", "blah");
        assert(error.msg == "test");
        assert(error.content == "blah");
    }
}

/**
 * Wiki/phriction API
 */
public class PhrictionAPI : PhabricatorAPI
{
    /**
     * Get page info
     */
    public JSONValue info(string slug)
    {
        auto req = DataRequest();
        req.data["slug"] = slug;
        return this.request(HTTP.Method.post,
                            Category.phriction,
                            "info",
                            &req);
    }

    /**
     * Edit a page
     */
    public JSONValue edit(string slug, string title, string content)
    {
        auto req = DataRequest();
        req.data["slug"] = slug;
        req.data["title"] = title;
        req.data["content"] = content;
        return this.request(HTTP.Method.post,
                            Category.phriction,
                            "edit",
                            &req);
    }
}

/**
 * Dashboard api
 */
public class DashboardAPI : PhabricatorAPI
{
    /**
     * Edit panel text
     */
    public JSONValue editText(string identifier, string text)
    {
        auto req = this.buildTrans(identifier,
                                   [tuple("custom.text", text)]);
        return this.request(HTTP.Method.post,
                            Category.dashboard,
                            "panel.edit",
                            &req);
    }
}

/**
 * File API
 */
public class FileAPI : PhabricatorAPI
{
    /**
     * Download a file
     */
    public JSONValue download(string phid)
    {
        auto req = DataRequest();
        req.data["phid"] = phid;
        return this.request(HTTP.Method.post,
                            Category.file,
                            "download",
                            &req);
    }
}

/**
 * Maniphest API for tasks
 */
public class ManiphestAPI : PhabricatorAPI
{
    // All tasks
    private enum AllQuery = "all";

    // Open tasks
    private enum OpenQuery = "open";

    /**
     * Compile a set of task results into a single output
     */
    private static JSONValue tasks(JSONValue[] results)
    {
        JSONValue stitched = JSONValue();
        stitched[ResultKey] = JSONValue();
        stitched[ResultKey][DataKey] = JSONValue();
        stitched[ResultKey][DataKey].array = [];
        foreach (obj; results)
        {
            foreach (key; obj.object.keys)
            {
                if (key == ResultKey)
                {
                    auto sub = obj.object[key];
                    foreach (subkey; sub.object.keys)
                    {
                        if (subkey == DataKey)
                        {
                            auto data = sub.object[subkey];
                            foreach (o; data.array)
                            {
                                stitched[ResultKey][DataKey].array ~= o;
                            }
                        }
                    }
                }
            }
        }

        return stitched;
    }

    /**
     * Comment on a task
     */
    public JSONValue comment(string phid, string text)
    {
        auto req = this.buildTrans(phid,
                                   [tuple("comment", text)]);
        return this.request(HTTP.Method.post,
                            Category.maniphest,
                            "edit",
                            &req);
    }

    /**
     * Open tasks
     */
    public JSONValue open()
    {
        return this.byQueryKey(OpenQuery);
    }

    /**
     * All tasks
     */
    public JSONValue all()
    {
        return this.byQueryKey(AllQuery);
    }

    /**
     * Get by query key
     */
    private JSONValue byQueryKey(string key)
    {
        auto req = DataRequest();
        req.data["queryKey"] = key;
        return this.getData("search", &req);
    }

    /**
     * Get data
     */
    private JSONValue getData(string call, DataRequest* req)
    {
        return this.paged(HTTP.Method.post,
                          Category.maniphest,
                          call,
                          req,
                          &tasks);
    }
}

/**
 * Diffusion api
 */
public class DiffusionAPI : PhabricatorAPI
{
    /**
     * Get file content by path, callsign, branch
     */
    public JSONValue fileContentByPathBranch(string path,
                                             string callsign,
                                             string branch)
    {
        string useCall = callsign;
        if (callsign.startsWith("r"))
        {
            useCall = callsign[1..callsign.length];
        }

        useCall = "r" ~ useCall.toUpper();
        auto req = DataRequest();
        req.data["path"] = path;
        req.data["callsign"] = useCall;
        req.data["branch"] = branch;
        return this.request(HTTP.Method.post,
                            Category.diffusion,
                            "filecontentquery",
                            &req);
    }
}

///
version(PhabUnitTest)
{
    /**
     * Testing API
     */
    public class TestAPI : PhabricatorAPI
    {
        /**
         * Cause an error
         */
        public JSONValue error()
        {
            return this.request(HTTP.Method.post,
                                Category.dashboard,
                                "error",
                                null);
        }

        /**
         * Get test data
         */
        public JSONValue get()
        {
            return this.request(HTTP.Method.post,
                                Category.dashboard,
                                "test",
                                null);
        }

        /**
         * Transaction testing
         */
        public DataRequest trans()
        {
            return this.buildTrans("test",
                                   [tuple("abc", "xyz"),
                                    tuple("123", "456")]);
        }

        unittest
        {
            auto api = new TestAPI();
            auto trans = api.trans();
            assert(trans.data.keys.length == 5);
            assert(trans.data["objectIdentifier"] == "test");
            assert(trans.data["transactions[0][type]"] == "abc");
            assert(trans.data["transactions[1][type]"] == "123");
            assert(trans.data["transactions[0][value]"] == "xyz");
            assert(trans.data["transactions[1][value]"] == "456");
        }
    }

    unittest
    {
        auto api = new TestAPI();
        api.url = "url";
        api.token = "token";
        auto resp = api.get();
        assert(resp.toJSON() == "{}");
        try
        {
            api.error();
            assert(false);
        }
        catch (PhabricatorAPIException e)
        {
            assert(e.msg == "Response error");
        }
    }
}

// Provides stitching of result sets together
alias JSONValue function(JSONValue[]) StitchFunction;

/**
 * API categories
 */
public enum Category : string
{
    // categories of the API methods
    phriction = "phriction", dashboard = "dashboard",
        diffusion = "diffusion", file = "file",
        maniphest = "maniphest"
}

/**
 * Phabricator API
 */
public abstract class PhabricatorAPI
{
    // conduit token
    @property public string token;

    // url/host to use
    @property public string url;

    // client timeout
    @property public int timeout;

    // init the instance
    this ()
    {
        this.timeout = 30;
    }

    /**
     * Build a transaction set
     */
    private DataRequest buildTrans(string id,
                                   Tuple!(string, string)[] objs)
    {
        auto req = DataRequest();
        req.data["objectIdentifier"] = id;
        int idx = 0;
        foreach (obj; objs)
        {
            auto trans = "transactions[" ~ to!string(idx) ~ "]";
            req.data[trans ~ "[type]"] = obj[0];
            req.data[trans ~ "[value]"] = obj[1];
            idx++;
        }

        return req;
    }

    /**
     * Data requests
     */
    public struct DataRequest
    {
        // post data
        string[string] data;
    }

    /**
     * Return paged data
     */
    private JSONValue paged(HTTP.Method method,
                            Category cat,
                            string call,
                            DataRequest* req,
                            StitchFunction stitch)
    {
        bool more = true;
        JSONValue[] results;
        string afterValue = null;
        req.data["order"] = "newest";
        while (more)
        {
            more = false;
            if (afterValue !is null)
            {
                req.data[AfterKey] = afterValue;
            }

            auto current = this.request(method, cat, call, req);
            results ~= current;
            if (CursorKey in current[ResultKey])
            {
                auto cursor = current[ResultKey][CursorKey];
                if (AfterKey in cursor)
                {
                    auto after = cursor[AfterKey];
                    if (!after.isNull)
                    {
                        afterValue = after.str;
                        more = true;
                    }
                }
            }
        }

        switch (results.length)
        {
            case 0:
                return parseJSON("{}");
            case 1:
                return results[0];
            default:
                return stitch(results);
        }
    }

    /**
     * Make a request
     */
    private JSONValue request(HTTP.Method method,
                              Category cat,
                              string call,
                              DataRequest* req)
    {
        if (this.token is null || this.token.length == 0 ||
            this.url is null || this.url.length == 0)
        {
            throw new PhabricatorAPIException("url and token are required");
        }

        string val = "";
        try
        {
            auto re = DataRequest();
            if (req !is null)
            {
                re = *req;
            }

            auto endpoint = this.url ~ "/api/" ~ cat ~ "." ~ call;
            bool curl = true;
            version(PhabUnitTest)
            {
                curl = false;
                import std.file: readText;
                import std.stdio;
                writeln(endpoint);
                auto text = readText("test/harness.json");
                auto test = parseJSON(text);
                if (endpoint in test)
                {
                    val = readText("test/" ~ test[endpoint].str ~ ".json");
                }
                else
                {
                    val = "{}";
                }
            }

            HTTP client = null;
            if (curl)
            {
                client = HTTP();
                client.operationTimeout = dur!"seconds"(this.timeout);
                client.addRequestHeader("ContentType", "application/json");
            }

            re.data["api.token"] = this.token;
            if (curl)
            {
                val = cast(string)post(endpoint, re.data, client);
            }

            version(PhabUnitTest)
            {
                import std.stdio;
                writeln(re.data);
            }

            auto json = parseJSON(val);
            if (ErrorCode in json)
            {
                if (!json[ErrorCode].isNull)
                {
                    throw new PhabricatorAPIException("Response error");
                }
            }

            return json;
        }
        catch (Exception e)
        {
            throw new PhabricatorAPIException(e.msg, val);
        }
    }
}
