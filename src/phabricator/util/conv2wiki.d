/**
 * Copyright 2017
 * MIT License
 * Convert objects to a wiki page
 */
module phabricator.util.conv2wiki;
import phabricator.api;
import phabricator.common;
import phabricator.util.diffusion;
import std.algorithm: sort;
import std.csv;
import std.stdio: writeln;
import std.string: endsWith, format, join, split;

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
 * Convert to a markdown table
 */
private abstract class Table : Converter
{
    /**
     * Setup the table (headers, spacers)
     */
    public string[] setup()
    {
        auto header = this.headers();
        string[] spacer;
        foreach (head; header)
        {
            spacer ~= "---";
        }

        return [toRow(header), toRow(spacer)];
    }

    /**
     * Convert an array to a table row
     */
    private static toRow(string[] values)
    {
        return "| " ~ join(values, " | ") ~ " |";
    }

    /**
     * Get the result records as a markdown table row
     */
    public string toRow()
    {
        return toRow(this.values());
    }

    /**
     * Get the header names
     */
    protected abstract string[] headers();
}

/**
 * Table made up of (name, alias, aka) columns
 */
private class NameAliasAlsoTable : Table
{
    // name of entity
    @property public string name;

    // alias value
    @property public string aliased;

    // aka/also aliased as
    @property public string also;

    // inherit doc
    public override string[] values()
    {
        return [this.name, this.aliased, this.also];
    }

    // inherit doc
    protected override string[] headers()
    {
        return ["name", "alias", "aka"];
    }
}

/**
 * Convert CSV input into a markdown table
 */
private static string[] table(T : Table)(string text)
    if (is(typeof(new T()) == T))
{
    string[] results;
    auto headers = new T();
    foreach (header; headers.setup())
    {
        results ~= header;
    }

    foreach (record; csvReader!NameAliasAlsoTable(text))
    {
        results ~= record.toRow();
    }

    return results;
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
 * Converters available
 */
public enum Conv
{
    // conversion functions
    catsub, raw, nameAlias
}

/**
 * Convert diffusion artifact to object
 */
public static bool wikiDiffusion(Settings settings,
                                 string header,
                                 string slug,
                                 string title,
                                 string path,
                                 string callsign,
                                 string branch,
                                 Conv method)
{
    try
    {
        if (!path.endsWith(".csv"))
        {
            throw new PhabricatorAPIException("only csv files are supported");
        }

        string[] vals;
        auto rawText = getDiffusion(settings, path, callsign, branch);
        switch (method)
        {
            case Conv.catsub:
                vals = catSubCat(rawText);
                break;
            case Conv.nameAlias:
                vals = table!NameAliasAlsoTable(rawText);
                break;
            default:
                vals = rawText.split("\n");
                break;
        }

        auto text = join(vals, "\n");
        auto phriction = construct!PhrictionAPI(settings);
        phriction.edit(slug, title, header ~ text);
        return true;
    }
    catch (Exception e)
    {
        writeln(e);
        return false;
    }
}
