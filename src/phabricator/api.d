/**
 * Copyright 2017
 * MIT License
 * Phabricator Conduit API
 */
module phabricator.api;
import core.time;
import std.json;
import std.net.curl;
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
        auto req = DataRequest();
        req.data["transactions[0][type]"] = "custom.text";
        req.data["transactions[0][value]"] = text;
        req.data["objectIdentifier"] = identifier;
        return this.request(HTTP.Method.post,
                            Category.dashboard,
                            "panel.edit",
                            &req);
    }
}

/**
 * API categories
 */
public enum Category : string
{
    // categories of the API methods
    phriction = "phriction", dashboard = "dashboard"
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
     * Data requests
     */
    public struct DataRequest
    {
        // post data
        string[string] data;
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
            version(MatrixUnitTest)
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
            val = cast(string)post(endpoint, re.data, client);
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
