package pl.ansible.lab;

import jakarta.ejb.Stateless;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;

import java.time.OffsetDateTime;
import java.util.List;

@Stateless
public class AppDataService {

    @PersistenceContext(unitName = "ansibleLabPU")
    private EntityManager entityManager;

    public List<AppData> findAll() {
        return entityManager
                .createQuery(
                        "SELECT a FROM AppData a ORDER BY a.id",
                        AppData.class
                )
                .getResultList();
    }

    public AppData create(String hostname) {
        AppData appData = new AppData(hostname, OffsetDateTime.now());
        entityManager.persist(appData);
        return appData;
    }
}
