/**
 * Copyright 2017
 * MIT License
 * diffusion utilities
 */
module phabricator.util.diffusion;
import phabricator.api;
import phabricator.common;
import std.base64;

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
