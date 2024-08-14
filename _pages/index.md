---
layout: page
title: Home
id: home
permalink: /
---

# Bienvenue Navid Jan !

> *Une promesse est une dette, et la plus grande fierté est de l'avoir honorée.* Hélal ^^

### [[Bourse de Paris &]]

<strong>Les notes récemment ajoutées : </strong>
<ul>
  {% assign recent_notes = site.notes | sort: "last_modified_at_timestamp" | reverse %}
  {% for note in recent_notes limit: 5 %}
    <li>
      {{ note.last_modified_at | date: "%Y-%m-%d" }} — <a class="internal-link" href="{{ site.baseurl }}{{ note.url }}">{{ note.title }}</a>
    </li>
  {% endfor %}
</ul>

<style>
  .wrapper {
    max-width: 46em;
  }
</style>

