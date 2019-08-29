/**
 * Strip the issue number in front of the commit message, 
 * this number is used later to generate a link to the Issue Management System 
 */
const ISSUE_NUMBER = /(#\d+)/g
const STRIP_ISSUE = /#\d+[,:]*/g
var hasIssues = 0

module.exports = function (data, callback) {
	const rewritten = data.commits.map((commit) => {
		const matches = commit.title.match(ISSUE_NUMBER);
		if (matches) {
			hasIssues = 1
			commit.issues = matches;
			// remove the issues from the title
			commit.title = commit.title.replace(STRIP_ISSUE, "");
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

