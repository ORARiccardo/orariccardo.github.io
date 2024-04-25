---
layout: activity
title: Activity Feed
permalink: /activity_feed/
---

<ul>
{% for post in site.posts %}
 <li><a href="{{ post.url }}">{{ post.title }}</a></li>
{% endfor %}
</ul>
