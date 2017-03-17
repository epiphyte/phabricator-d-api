/**
 * Copyright 2017
 * MIT License
 * Convert objects to a wiki page
 */
module phabricator.conv2wiki;
import phabricator.api;
import phabricator.common;
import std.algorithm: sort;
import std.csv;
import std.stdio: writeln;
import std.string: endsWith, format;

/**
 * Base converter
 */
private abstract class Converter
{
    // get raw values
    public abstract string[] values();
}

/**
 * Converter for cat,subcat,name,details
 */
private class CatSubCat : Converter
{
    // format children
    public enum Format = "```\n%s%s%s\n```";

    // note entry
    public enum NoteEntry = "Note";

    // category for entity
    @property public string cat;

    // sub cat for entity
    @property public string sub;

    // name of entity
    @property public string name;

    // details for line
    @property public string detail;

    // inherit doc
    public override string[] values()
    {
        return [this.cat, this.sub, this.name, this.detail];
    }
}

/**
 * Tree conversion object
 */
private class Tree
{
    // node name
    @property public string name;

    // node value
    @property public string val;

    // meta description
    @property public string meta;

    // leaves or children
    @property public Tree[string] leaves;
}

/**
 * Use CatSubCat for conversion
 */
private static string[] catSubCat(string text)
{
    auto obj = new Tree();
    foreach (record; csvReader!CatSubCat(text))
    {
        if (record.cat !in obj.leaves)
        {
            obj.leaves[record.cat] = new Tree();
        }

        auto sub = obj.leaves[record.cat];
        if (record.sub !in sub.leaves)
        {
            sub.leaves[record.sub] = new Tree();
        }

        auto leaf = sub.leaves[record.sub];
        if (record.name == CatSubCat.NoteEntry)
        {
            leaf.meta = record.detail;
        }
        else
        {
            if (record.name !in leaf.leaves)
            {
                auto child = new Tree();
                child.name = record.name;
                child.val = record.detail;
                leaf.leaves[record.name] = child;
            }
        }

        sub.leaves[record.sub] = leaf;
        obj.leaves[record.cat] = sub;
    }

    string[] outputs;
    foreach (top; obj.leaves.keys.sort!("a < b"))
    {
        outputs ~= "\n---\n";
        outputs ~= "# " ~ top;
        outputs ~= "\n---\n";
        auto subs = obj.leaves[top];
        foreach (sub; subs.leaves.keys.sort!("a < b"))
        {
            outputs ~= "\n## " ~ sub ~ "\n";
            auto subObj = subs.leaves[sub];
            if (subObj.meta !is null && subObj.meta.length > 0)
            {
                outputs ~= format(CatSubCat.Format, subObj.meta, "", "");
            }

            foreach (child; subObj.leaves.keys.sort!("a < b"))
            {
                auto node = subObj.leaves[child];
                outputs ~= format(CatSubCat.Format, node.name, "\n", node.val);
            }
        }
    }

    return outputs;
}

/**
 * Convert diffusion artifact to object
 */
public static bool wikiDiffusion(Settings settings,
                                 string slug,
                                 string title,
                                 string path,
                                 string callsign,
                                 string branch,
                                 string output)
{
    try
    {
        if (!path.endsWith(".csv"))
        {
            throw new PhabricatorAPIException("only csv files are supported");
        }

        auto text = getDiffusion(settings, path, callsign, branch);
        return true;
    }
    catch (Exception e)
    {
        writeln(e);
        return false;
    }
}
