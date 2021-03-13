import json

with open('works.json') as json_file:
	data = json.load(json_file)
	medium_list = []
	for work_slug, work in data.items():
		with open("work_files/" + work_slug + ".md", "w") as f:
			f.write("---\ntitle: " + work['name'] + "\npermalink: /works/" + work_slug + "\n---")
			f.close

		for medium in work['mediums']:
			if medium not in medium_list:
				medium_list.append(medium)

for medium in medium_list:
	medium_name = medium.replace("-", " ")
	with open("medium_files/" + medium + ".md", "w") as f:
		f.write("---\ntitle: " + medium_name + "\nmedium: " + medium + "\npermalink: /works/" + medium + "\n---")
		f.close