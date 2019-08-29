/**
 * Using the GUS Workitem W-123456 to generate a link to GUS
 */
const WORK_ITEM = /([A-Z]+-\d+)/g
const DEL_ISSUE = /[A-Z]+-\d+[,:]*/g
const RM_PREFIX = /^[a-zA-Z]+-/
var hasIssues = 0

module.exports = function (data, callback) {
	const rewritten = data.commits.map((commit) => {
		const matches = commit.title.match(WORK_ITEM);
		if (matches) {
			hasIssues = 1
			commit.issues = matches;
			// remove the issues from the title
			commit.title = commit.title.replace(DEL_ISSUE, "");
		}

		return commit;
	});
	

	callback({
		commits: rewritten,
		hasIssues: hasIssues,
        range: data.range,
		range_since: data.range.split("..")[0],
        range_until: data.range.split("..")[1]
	});
}

