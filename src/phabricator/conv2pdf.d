/**
 * Copyright 2017
 * MIT License
 * Supports converting phabricator objects to pdf
 */
module phabricator.conv2pdf;
import phabricator.api;
import phabricator.common;
import std.file: write;
import std.process: execute;
import std.stdio: writeln;
import std.string: indexOf, replace;

/**
 * Convert to pdf
 */
private static bool convert(string document, string output)
{
    auto outputDoc = document;
    while (outputDoc.indexOf("**") >= 0)
    {
        outputDoc = outputDoc.replace("**", "\t*");
    }

    auto saveTo = output ~ ".md";
    write(saveTo, outputDoc);
    auto res = execute(["pandoc",
                        saveTo,
                        "--output",
                         output ~ ".pdf",
                        "--smart",
                        "-V",
                        "geometry:margin=0.8in"]);
    writeln(res);
    return res.status == 0;
}

/**
 * Convert a slug to a panel
 */
public static bool convertPhriction(Settings settings,
                                    string slug,
                                    string output)
{
    try
    {
        auto wiki = construct!PhrictionAPI(settings);
        auto page = wiki.info(slug)[ResultKey][ContentKey].str;
        return convert(page, output);
    }
    catch (Exception e)
    {
        writeln(e);
        return false;
    }
}
