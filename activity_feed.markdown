---
layout: activity
title: Activity Feed
permalink: /activity_feed/
---

{% for post in site.posts %}
<div class="card">
<div class="card-body">
<div class="card-text d-flex">
<i class="align-self-center bi bi-lightning-fill"></i>
<div>
<a class="main-link" href="{{ post.url | relative_url }}">{{ post.title }}</a>
{{ post.content }}
</div>
</div>
</div>
</div>
{% endfor %}
