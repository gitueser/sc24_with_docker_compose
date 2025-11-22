package ag.selm.eureka.config;

import jakarta.annotation.Priority;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.annotation.web.configurers.CsrfConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityBeans {

    @Bean
    @Order(0)
    SecurityFilterChain api(HttpSecurity http) throws Exception {
        return http
                .securityMatcher("/eureka/apps/**")
                .authorizeHttpRequests(a -> a
                        .requestMatchers(HttpMethod.GET, "/eureka/apps/**").permitAll()
                        .requestMatchers(HttpMethod.HEAD, "/eureka/apps/**").permitAll()
                        .requestMatchers(HttpMethod.OPTIONS, "/eureka/apps/**").permitAll()
                        .anyRequest().hasAuthority("SCOPE_discovery"))
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .oauth2ResourceServer(o -> o.jwt(Customizer.withDefaults()))
                .build();
    }
//    @Priority(0)
//    public SecurityFilterChain apiSecurityFilterChain(HttpSecurity http) throws Exception {
//        return http
//                .securityMatcher("/eureka/apps", "/eureka/apps/**")
//                .authorizeHttpRequests(customizer -> customizer.anyRequest()
//                        .hasAuthority("SCOPE_discovery"))
//                .sessionManagement(customizer -> customizer.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
//                .csrf(CsrfConfigurer::disable)
//                .oauth2ResourceServer(customizer -> customizer.jwt(Customizer.withDefaults()))
//                .build();
//    }

    @Bean
//    @Priority(1)
    @Order(1)
    public SecurityFilterChain mainSecurityFilterChain(HttpSecurity http) throws Exception {
        return http
                .authorizeHttpRequests(a -> a
                        .requestMatchers(
                                "/",              // корень UI
                                "/eureka/**",     // ресурсы UI (css/js/img) — разные сборки кладут их под /eureka
                                "/assets/**",     // иногда статика тут
                                "/webjars/**",
                                "/favicon.ico",
                                "/actuator/health"
                        ).permitAll()
                        .anyRequest().authenticated()
                )
                .oauth2Login(o -> o.defaultSuccessUrl("/", true))
                .build();

//        return http
//                .authorizeHttpRequests(customizer -> customizer.anyRequest().authenticated())
//                .oauth2Login(Customizer.withDefaults())
//                .build();
    }
}
