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
import std.string: format, join, startsWith, toUpper;
import std.typecons;
import std.uri;

// error code key
private enum ErrorCode = "error_code";

// Posting code prefix for mixin
private enum PostPrefix = "val = cast(string)post(endpoint, ";

// Posting code suffix for mixin
private enum PostSuffix = ", client);";

// Encoded data from request
private enum PostEncoded = PostPrefix ~ "encoded" ~ PostSuffix;

// Mapped values from request data
private enum PostMapped = PostPrefix ~ "mapped" ~ PostSuffix;

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
 * Remarkup API
 */
public class RemarkupAPI : PhabricatorAPI
{
    /**
     * Process text
     */
    public JSONValue process(string context, string[] text)
    {
        auto req = DataRequest();
        req.data["context"] = context;
        int idx = 0;
        foreach (item; text)
        {
            req.data["contents[" ~ to!string(idx) ~ "]"] = item;
            idx++;
        }

        return this.request(HTTP.Method.post,
                            Category.remarkup,
                            "process",
                            &req);
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
                                   [tuple("custom.text", text, false)]);
        return this.request(HTTP.Method.post,
                            Category.dashboard,
                            "panel.edit",
                            &req);
    }
}

/**
 * Project API
 */
public class ProjectAPI : PhabricatorAPI
{
    /**
     * Add a member to a project
     */
    public JSONValue addMember(string projectPHID, string userPHID)
    {
        auto req = this.buildTrans(projectPHID,
                                   [tuple("members.add", userPHID, true)]);
        return this.request(HTTP.Method.post,
                            Category.project,
                            "edit",
                            &req);
    }

    /**
     * Active projects
     */
    public JSONValue active()
    {
        // NOTE: needs to eventually support paging
        auto req = this.fromKey("active");
        return this.request(HTTP.Method.post,
                            Category.project,
                            "search",
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
        return this.edit(phid, [tuple("comment", text, false)]);
    }

    /**
     * Edit a task
     */
    private JSONValue edit(string phid, Tuple!(string, string, bool)[] trans)
    {
        auto req = this.buildTrans(phid, trans);
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
     * Open by project
     */
    public JSONValue openProject(string projectPHID)
    {
        return this.openConstrained(projectPHID);
    }

    /**
     * Open and subscribed projects
     */
    public JSONValue openSubscribedProject(string projectPHID, string userPHID)
    {
        return this.openConstrained(projectPHID, userPHID);
    }

    /**
     * Add a project to a task
     */
    public JSONValue addProject(string phid, string projectPHID)
    {
        return this.edit(phid, [tuple("projects.add", projectPHID, true)]);;
    }

    /**
     * Invalidate a task
     */
    public JSONValue invalid(string phid)
    {
        return this.edit(phid, [tuple("status", "invalid", false)]);
    }

    /**
     * Open query but with constraints
     */
    private JSONValue openConstrained(string projectPHIDs,
                                      string ccPHIDs = null)
    {
        string[string] constraints;
        if (projectPHIDs !is null)
        {
            constraints["projects"] = projectPHIDs;
        }

        if (ccPHIDs !is null)
        {
            constraints["subscribers"] = ccPHIDs;
        }

        auto req = this.getQuery(OpenQuery, constraints);
        return this.search(req);
    }

    /**
     * All tasks
     */
    public JSONValue all()
    {
        return this.byQueryKey(AllQuery);
    }

    /**
     * Get all, by identifier
     */
    public JSONValue byIds(int[] identifiers)
    {
        auto req = this.getQuery(AllQuery);
        if (identifiers !is null && identifiers.length > 0)
        {
            DataRequest.KeyValue[] function(string[]) iterate =
                   function DataRequest.KeyValue[](string[] state)
            {
                int idx = 0;
                DataRequest.KeyValue[] objs;
                foreach (id; state)
                {
                    auto obj = DataRequest.KeyValue();
                    obj.key = "constraints[ids][" ~ to!string(idx) ~ "]";
                    obj.value = id;
                    objs ~= obj;
                    idx++;
                }

                return objs;
            };

            req.urlFunction = iterate;
            foreach (id; identifiers)
            {
                req.raw ~= to!string(id);
            }
        }

        req.urlEncode = true;
        return this.search(req);
    }

    /**
     * Get a query request with key and constraints (optional)
     */
    private DataRequest getQuery(string key, string[string] constraints = null)
    {
        auto req = this.fromKey(key);
        if (constraints !is null)
        {
            foreach (val; constraints.keys)
            {
                req.data["constraints[" ~ val ~ "][0]"] = constraints[val];
            }
        }

        return req;
    }

    /**
     * Get by query key
     */
    public JSONValue byQueryKey(string key)
    {
        auto req = this.getQuery(key);
        return this.search(req);
    }

    /**
     * Search requests
     */
    private JSONValue search(DataRequest req)
    {
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
                                   [tuple("abc", "xyz", true),
                                    tuple("123", "456", false)]);
        }

        unittest
        {
            auto api = new TestAPI();
            auto trans = api.trans();
            assert(trans.data.keys.length == 5);
            assert(trans.data["objectIdentifier"] == "test");
            assert(trans.data["transactions[0][type]"] == "abc");
            assert(trans.data["transactions[1][type]"] == "123");
            assert(trans.data["transactions[0][value][]"] == "xyz");
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
        maniphest = "maniphest", user = "user",
        project = "project", remarkup = "remarkup",
        paste = "paste"
}

/**
 * User API
 */
public class UserAPI : PhabricatorAPI
{
    /**
     * Get user information
     */
    deprecated("user.whoami is being deprecated upstream")
        public JSONValue whoami()
    {
        return this.request(HTTP.Method.post,
                            Category.user,
                            "whoami",
                            null);
    }

    /**
     * Get active users
     */
    public JSONValue activeUsers()
    {
        auto req = this.fromKey("active");
        req.data["constraints[isBot]"] = "0";
        return this.search(&req);
    }

    /**
     * Perform a search operation
     */
    private JSONValue search(DataRequest* req)
    {
        return this.request(HTTP.Method.post,
                            Category.user,
                            "search",
                            req);
    }
}

/**
 * Paste API
 */
public class PasteAPI : PhabricatorAPI
{
    /**
     * Edit paste text
     */
    public JSONValue editText(string phid, string text)
    {
        auto req = this.buildTrans(phid,
                                   [tuple("text", text, false)]);
        return this.request(HTTP.Method.post,
                            Category.paste,
                            "edit",
                            &req);
    }

    /**
     * Get an active paste by phid
     */
    public JSONValue activeByPHID(string phid, bool withContent = true)
    {
        auto req = this.fromKey("active");
        req.data["constraints[phids][0]"] = phid;
        if (withContent)
        {
            req.data["attachments[content]"] = "1";
        }

        return this.request(HTTP.Method.post,
                            Category.paste,
                            "search",
                            &req);
    }
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

    // user PHID
    @property public string userPHID;

    // client timeout
    @property public int timeout;

    // init the instance
    this ()
    {
        this.timeout = 30;
    }

    /**
     * Build request from query key
     */
    private DataRequest fromKey(string key)
    {
        auto req = DataRequest();
        req.data["queryKey"] = key;
        return req;
    }

    /**
     * Build a transaction set
     */
    private DataRequest buildTrans(string id,
                                   Tuple!(string, string, bool)[] objs)
    {
        auto req = DataRequest();
        req.data["objectIdentifier"] = id;
        int idx = 0;
        foreach (obj; objs)
        {
            auto trans = "transactions[" ~ to!string(idx) ~ "]";
            req.data[trans ~ "[type]"] = obj[0];
            string vals = trans ~ "[value]";
            if (obj[2])
            {
                vals = vals ~ "[]";
            }

            req.data[vals] = obj[1];
            idx++;
        }

        return req;
    }

    /**
     * Data requests
     */
    public struct DataRequest
    {
        /**
         * Key/Value pair
         */
        public struct KeyValue
        {
            // key of item
            string key;

            // value of item
            string value;
        }

        // post data
        string[string] data;

        // using URL encoded data
        bool urlEncode = false;

        // encoded data
        string encoded;

        // Raw values to encode
        string[] raw;

        // URL encoding function to get key/value pairs to encode
        KeyValue[] function(string[] input) urlFunction;

        // encode the internal url as set
        void encode()
        {
            this.encoded = "";
            if (!this.urlEncode)
            {
                return;
            }

            if (this.raw.length > 0 && this.urlFunction !is null)
            {
                string[] results;
                foreach (obj; this.urlFunction(this.raw))
                {
                    results ~= format("%s=%s", obj.key, obj.value);
                }

                this.encoded = join(results, "&");
            }

            if (this.urlEncode && this.encoded.length == 0)
            {
                throw new PhabricatorAPIException("URL encoded but no values");
            }
        }

        // Settings that are temporal to request and not initial data requests
        string[string] temporal;
    }

///
version(PhabUnitTest)
{
    unittest
    {
        auto req = DataRequest();
        req.encode();
        assert(req.encoded == "");
        req.urlEncode = true;
        try
        {
            req.encode();
            assert(false);
        }
        catch (PhabricatorAPIException e)
        {
            assert(e.msg == "URL encoded but no values");
        }

        req.raw ~= "test";
        try
        {
            req.encode();
            assert(false);
        }
        catch (PhabricatorAPIException e)
        {
            assert(e.msg == "URL encoded but no values");
        }

        DataRequest.KeyValue[] function(string[]) fxn =
            function DataRequest.KeyValue[](string[] state)
        {
            DataRequest.KeyValue[] objs;
            foreach (obj; state)
            {
                auto test = DataRequest.KeyValue();
                test.key = "test";
                test.value = obj;
                objs ~= test;
            }

            return objs;
        };

        req.urlFunction = fxn;
        req.encode();
        assert(req.encoded == "test=test");
        req.raw ~= "test2";
        req.encode();
        assert(req.encoded == "test=test&test=test2");
    }
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
        while (more)
        {
            req.temporal["order"] = "newest";
            more = false;
            if (afterValue !is null)
            {
                req.temporal[AfterKey] = afterValue;
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

            re.encode();
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

            if (curl)
            {
                auto tokens = re.temporal;
                tokens["api.token"] = this.token;
                if (re.urlEncode)
                {
                    string encoded = re.encoded;
                    foreach (token; tokens.byKey())
                    {
                        encoded = encoded ~ "&" ~ token ~ "=" ~ tokens[token];
                    }

                    mixin(PostEncoded);
                }
                else
                {
                    string[string] mapped;
                    foreach (key; re.data.byKey())
                    {
                        mapped[key] = re.data[key];
                    }

                    foreach (token; tokens.byKey())
                    {
                        mapped[token] = tokens[token];
                    }

                    mixin(PostMapped);
                }

                // drop the temporal keys
                foreach (key; re.temporal.keys)
                {
                    re.temporal.remove(key);
                }
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
