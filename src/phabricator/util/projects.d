/**
 * Copyright 2017
 * MIT License
 * Project util helpers
 */
module phabricator.util.projects;
import phabricator.api;
import phabricator.common;

/**
 * Assign a user to all active projects
 */
public static bool assignToActive(Settings settings, string userPHID)
{
    try
    {
        auto proj = construct!ProjectAPI(settings);
        auto actives = proj.active()[ResultKey][DataKey].array;
        foreach (active; actives)
        {
            try
            {
                proj.addMember(active["phid"].str, userPHID);
            }
            catch (PhabricatorAPIException e)
            {
                // Ignore phabricator API exceptions
            }
        }

        return true;
    }
    catch (Exception e)
    {
        return false;
    }
}
